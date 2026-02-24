#!/usr/bin/env python3
"""
Client Sheet → DB Sync Script
==============================
Reads the BsB client directory Google Sheet and syncs all rows to the
PostgreSQL database using upsert_client and upsert_client_code.

Run this whenever new clients are added to the sheet to keep the DB in sync.
Safe to re-run — all operations are upserts (existing records are updated,
not duplicated).

Usage:
    python3 scripts/sync_client_sheet.py            # dry-run (no DB changes)
    python3 scripts/sync_client_sheet.py --apply    # write to DB

Notes:
- TLA is derived from the client code by stripping trailing digits (ELR001 → ELR)
- Requires re-authentication if token.json was created without Sheets scope:
  delete scripts/token.json and re-run to trigger browser auth
"""

import os
import re
import sys
import argparse

import psycopg2
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow

# ── Constants ──────────────────────────────────────────────────────────────────

SCOPES = [
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/spreadsheets.readonly',
]
SHEET_ID    = '1hSSJCG-QR6R6XIyB-CrxryDhA3_XqBt-SqhG9Oqy96E'
SHEET_RANGE = 'A:L'

TOKEN_FILE   = os.path.join(os.path.dirname(__file__), 'token.json')
SECRETS_FILE = os.path.join(os.path.dirname(__file__), 'client_secrets.json')

# Column indices (0-based) matching sheet header order:
# BsB Client Code | Client Name | Primary contact | Primary Contact Email |
# Other People in this Client Code | Payment Terms | PO Required? |
# Client Billing contact | Client Billing email | Client Billing Address |
# Notes | Formatted Client Name
COL = {
    'bsb_client_code':        0,
    'client_name':            1,
    'primary_contact':        2,
    'primary_contact_email':  3,
    'other_people':           4,
    'payment_terms':          5,
    'po_required':            6,
    'billing_contact':        7,
    'billing_email':          8,
    'billing_address':        9,
    'notes':                  10,
    'formatted_client_name':  11,
}


# ── Env loader ────────────────────────────────────────────────────────────────

def _load_env():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    for name in ('.env', 'scripts.env'):
        env_path = os.path.join(script_dir, name)
        if os.path.exists(env_path):
            with open(env_path) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#') or '=' not in line:
                        continue
                    key, _, value = line.partition('=')
                    os.environ.setdefault(key.strip(), value.strip())
            break

_load_env()


# ── Auth ───────────────────────────────────────────────────────────────────────

def get_sheets_service():
    creds = None
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception:
                creds = None

        if not creds or not creds.valid:
            if not os.path.exists(SECRETS_FILE):
                print(f"ERROR: {SECRETS_FILE} not found.")
                print("See audit_drive_folders.py docstring for setup instructions.")
                sys.exit(1)
            flow = InstalledAppFlow.from_client_secrets_file(SECRETS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)

        with open(TOKEN_FILE, 'w') as f:
            f.write(creds.to_json())

    return build('sheets', 'v4', credentials=creds)


# ── DB ─────────────────────────────────────────────────────────────────────────

def get_db_connection():
    return psycopg2.connect(
        host=os.environ['DB_HOST'],
        dbname=os.environ.get('DB_NAME', 'bitesize_bio'),
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASS'],
        port=int(os.environ.get('DB_PORT', 5432)),
        connect_timeout=15,
    )


# ── Helpers ────────────────────────────────────────────────────────────────────

def extract_tla(client_code):
    """Strip trailing digits to get TLA: ELR001 → ELR, N6T001 → N6T."""
    m = re.match(r'^([A-Z0-9]+?)(\d{3,4})$', client_code.strip().upper())
    return m.group(1) if m else None


def cell(row, key):
    """Return stripped cell value or None if empty/missing."""
    idx = COL[key]
    val = row[idx].strip() if idx < len(row) else ''
    return val if val else None


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Sync client directory sheet to DB')
    parser.add_argument('--apply', action='store_true',
                        help='Write to DB (default: dry-run)')
    args = parser.parse_args()

    print(f"Mode: {'APPLY' if args.apply else 'DRY-RUN'}\n")

    service = get_sheets_service()

    try:
        conn = get_db_connection()
    except KeyError as e:
        print(f"ERROR: missing env var {e}. Set DB_HOST, DB_NAME, DB_USER, DB_PASS.")
        sys.exit(1)

    cur = conn.cursor()

    # Read sheet
    result = service.spreadsheets().values().get(
        spreadsheetId=SHEET_ID,
        range=SHEET_RANGE,
    ).execute()

    rows = result.get('values', [])
    if not rows:
        print("No data found in sheet.")
        return

    data_rows = rows[1:]  # skip header row
    print(f"Read {len(data_rows)} rows from sheet\n")

    clients_seen = set()
    codes_ok = 0
    errors = []

    for i, row in enumerate(data_rows, start=2):
        code_val = cell(row, 'bsb_client_code')
        if not code_val:
            continue

        tla = extract_tla(code_val)
        if not tla:
            print(f"  [SKIP] Row {i}: can't extract TLA from '{code_val}'")
            continue

        client_name      = cell(row, 'client_name') or code_val
        formatted_name   = cell(row, 'formatted_client_name')

        # Upsert client once per TLA
        if tla not in clients_seen:
            clients_seen.add(tla)
            print(f"  [CLIENT] {tla} — {client_name}")
            if args.apply:
                try:
                    cur.execute(
                        "SELECT upsert_client(%s, %s, %s)",
                        (tla, client_name, formatted_name)
                    )
                except Exception as e:
                    errors.append(f"Row {i} upsert_client({tla}): {e}")
                    conn.rollback()
                    print(f"    ERROR: {e}")
                    continue

        # Upsert client code
        contact = cell(row, 'primary_contact')
        print(f"    [CODE] {code_val}{' — ' + contact if contact else ''}")
        if args.apply:
            try:
                cur.execute(
                    "SELECT upsert_client_code(%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (
                        code_val,
                        tla,
                        contact,
                        cell(row, 'primary_contact_email'),
                        cell(row, 'payment_terms'),
                        cell(row, 'po_required'),
                        cell(row, 'billing_contact'),
                        cell(row, 'billing_email'),
                        cell(row, 'billing_address'),
                    )
                )
                codes_ok += 1
            except Exception as e:
                errors.append(f"Row {i} upsert_client_code({code_val}): {e}")
                conn.rollback()
                print(f"    ERROR: {e}")

    if args.apply:
        conn.commit()

    print(f"\n{'Written' if args.apply else 'Would write'}:")
    print(f"  {len(clients_seen)} unique client TLA(s)")
    print(f"  {codes_ok if args.apply else len(data_rows)} client code row(s)")

    if errors:
        print(f"\n{len(errors)} error(s):")
        for err in errors:
            print(f"  {err}")

    cur.close()
    conn.close()


if __name__ == '__main__':
    main()
