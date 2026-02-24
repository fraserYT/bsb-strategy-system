#!/usr/bin/env python3
"""
Drive Folder Audit Script
=========================
Scans the Client Projects folder in Google Drive, matches folders to DB records
(by TLA for Tier 1, by client code for Tier 2), and optionally updates
drive_folder_id fields in the database.

Setup
-----
1. Get client_secrets.json:
   - Go to console.cloud.google.com
   - Select (or create) a project
   - APIs & Services → Enable → "Google Drive API"
   - APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID
   - Application type: Desktop app
   - Download JSON → save as client_secrets.json in this directory

2. Set DB environment variables (or create a .env file and source it):
   export DB_HOST=your-sevalla-host
   export DB_NAME=bitesize_bio
   export DB_USER=your-db-user
   export DB_PASS=your-db-password
   # DB_PORT defaults to 5432

3. Run (dry-run first):
   python3 scripts/audit_drive_folders.py

4. Review audit_results.csv, then apply:
   python3 scripts/audit_drive_folders.py --apply

Options
-------
  --apply        Write updates to DB (default is dry-run)
  --tier2        Also scan Tier 2 subfolders (slower — one API call per Tier 1 folder)
  --output FILE  CSV output path (default: audit_results.csv)
"""

import os
import re
import csv
import sys
import argparse
from collections import Counter

# ── Load .env file if present ─────────────────────────────────────────────────

def _load_env():
    """Load key=value pairs from scripts/.env or scripts/scripts.env into os.environ."""
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

import psycopg2
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow

# ── Constants ──────────────────────────────────────────────────────────────────

SCOPES = ['https://www.googleapis.com/auth/drive.readonly']
CLIENT_PROJECTS_FOLDER_ID = '1PURGWZSK1gMTJN7GDYogY1Q0_ohsUkht'
SHARED_DRIVE_ID = '0AB1AZiOLJI_ZUk9PVA'
TOKEN_FILE = os.path.join(os.path.dirname(__file__), 'token.json')
SECRETS_FILE = os.path.join(os.path.dirname(__file__), 'client_secrets.json')

# Tier 1: [TLA] Client Name  (TLA = 2–5 uppercase letters)
TIER1_RE = re.compile(r'^\[([A-Z]{2,5})\]\s+(.+)$')

# Tier 2: [CODE] Contact Name  (CODE = letters + digits, e.g. ABC001, ZEI003)
TIER2_RE = re.compile(r'^\[([A-Z]{2,5}\d{3,4})\]\s+(.+)$')


# ── Google Drive auth ──────────────────────────────────────────────────────────

def get_drive_service():
    creds = None

    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(SECRETS_FILE):
                print(f"ERROR: {SECRETS_FILE} not found.")
                print("See script docstring for setup instructions.")
                sys.exit(1)
            flow = InstalledAppFlow.from_client_secrets_file(SECRETS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)

        with open(TOKEN_FILE, 'w') as f:
            f.write(creds.to_json())

    return build('drive', 'v3', credentials=creds)


# ── Drive helpers ──────────────────────────────────────────────────────────────

def list_folders(service, parent_id):
    """Return all (non-trashed) subfolders of parent_id in the Shared Drive."""
    folders = []
    page_token = None
    while True:
        resp = service.files().list(
            q=(
                f"'{parent_id}' in parents"
                " and mimeType='application/vnd.google-apps.folder'"
                " and trashed=false"
            ),
            fields='nextPageToken, files(id, name)',
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
            corpora='drive',
            driveId=SHARED_DRIVE_ID,
            pageToken=page_token,
        ).execute()
        folders.extend(resp.get('files', []))
        page_token = resp.get('nextPageToken')
        if not page_token:
            break
    return folders


# ── DB helpers ─────────────────────────────────────────────────────────────────

def get_db_connection():
    return psycopg2.connect(
        host=os.environ['DB_HOST'],
        dbname=os.environ.get('DB_NAME', 'bitesize_bio'),
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASS'],
        port=int(os.environ.get('DB_PORT', 5432)),
        connect_timeout=15,
    )


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Audit Drive folder structure against DB')
    parser.add_argument('--apply', action='store_true',
                        help='Write folder IDs to DB (default: dry-run)')
    parser.add_argument('--tier2', action='store_true',
                        help='Also scan Tier 2 subfolders (slower)')
    parser.add_argument('--output', default='audit_results.csv',
                        help='CSV output file (default: audit_results.csv)')
    args = parser.parse_args()

    print(f"Mode: {'APPLY' if args.apply else 'DRY-RUN'}")
    print(f"Tier 2 scan: {'yes' if args.tier2 else 'no (pass --tier2 to enable)'}\n")

    service = get_drive_service()

    try:
        conn = get_db_connection()
    except KeyError as e:
        print(f"ERROR: missing environment variable {e}")
        print("Set DB_HOST, DB_NAME, DB_USER, DB_PASS (and optionally DB_PORT).")
        sys.exit(1)

    cur = conn.cursor()

    # Load DB records
    cur.execute("SELECT id, tla, client_name, drive_folder_id FROM clients WHERE tla IS NOT NULL")
    clients_by_tla = {
        row[1]: {'id': row[0], 'name': row[2], 'existing_folder_id': row[3]}
        for row in cur.fetchall()
    }

    codes_by_code = {}
    if args.tier2:
        cur.execute("SELECT id, bsb_client_code, drive_folder_id FROM bsb_client_codes")
        codes_by_code = {
            row[1]: {'id': row[0], 'existing_folder_id': row[2]}
            for row in cur.fetchall()
        }

    results = []

    # ── Tier 1 ────────────────────────────────────────────────────────────────
    print(f"Scanning Client Projects ({CLIENT_PROJECTS_FOLDER_ID})...")
    tier1_folders = list_folders(service, CLIENT_PROJECTS_FOLDER_ID)
    print(f"Found {len(tier1_folders)} Tier 1 folders\n")

    for folder in sorted(tier1_folders, key=lambda f: f['name']):
        name = folder['name']
        folder_id = folder['id']
        row = {'tier': 1, 'name': name, 'folder_id': folder_id,
               'tla': '', 'code': '', 'status': '', 'note': ''}

        match = TIER1_RE.match(name)
        if not match:
            row['status'] = 'NON_CONFORMING'
            row['note'] = 'Name does not match [TLA] pattern'
            results.append(row)
            print(f"  [SKIP] {name}")
            continue

        tla = match.group(1)
        row['tla'] = tla

        if tla not in clients_by_tla:
            row['status'] = 'TLA_NOT_FOUND'
            row['note'] = f'TLA "{tla}" not in clients table'
            results.append(row)
            print(f"  [MISS] {name} — TLA {tla} not in DB")
            continue

        client = clients_by_tla[tla]
        existing = client['existing_folder_id']

        if existing and existing != folder_id:
            row['status'] = 'CONFLICT'
            row['note'] = f'DB already has folder_id {existing}'
            results.append(row)
            print(f"  [CONF] {name} — DB has different folder ID")
        elif existing == folder_id:
            row['status'] = 'ALREADY_SET'
            results.append(row)
            print(f"  [OK]   {name}")
        else:
            row['status'] = 'UPDATE'
            results.append(row)
            print(f"  [UPD]  {name}")
            if args.apply:
                cur.execute(
                    "UPDATE clients SET drive_folder_id = %s WHERE id = %s",
                    (folder_id, client['id'])
                )

        # ── Tier 2 ────────────────────────────────────────────────────────────
        if args.tier2:
            tier2_folders = list_folders(service, folder_id)
            for sub in sorted(tier2_folders, key=lambda f: f['name']):
                sub_name = sub['name']
                sub_id = sub['id']
                sub_row = {'tier': 2, 'name': sub_name, 'folder_id': sub_id,
                           'tla': tla, 'code': '', 'status': '', 'note': ''}

                sub_match = TIER2_RE.match(sub_name)
                if not sub_match:
                    sub_row['status'] = 'NON_CONFORMING'
                    sub_row['note'] = 'Name does not match [CODE] pattern'
                    results.append(sub_row)
                    continue

                code = sub_match.group(1)
                sub_row['code'] = code

                if code not in codes_by_code:
                    sub_row['status'] = 'CODE_NOT_FOUND'
                    sub_row['note'] = f'Code "{code}" not in bsb_client_codes'
                    results.append(sub_row)
                    continue

                cc = codes_by_code[code]
                sub_existing = cc['existing_folder_id']

                if sub_existing and sub_existing != sub_id:
                    sub_row['status'] = 'CONFLICT'
                    sub_row['note'] = f'DB already has folder_id {sub_existing}'
                elif sub_existing == sub_id:
                    sub_row['status'] = 'ALREADY_SET'
                else:
                    sub_row['status'] = 'UPDATE'
                    if args.apply:
                        cur.execute(
                            "UPDATE bsb_client_codes SET drive_folder_id = %s WHERE id = %s",
                            (sub_id, cc['id'])
                        )

                results.append(sub_row)

    if args.apply:
        conn.commit()
        print("\nChanges committed to DB.")
    else:
        print("\nDry-run complete — no DB changes made. Pass --apply to write to DB.")

    # Write CSV
    fieldnames = ['tier', 'name', 'folder_id', 'tla', 'code', 'status', 'note']
    with open(args.output, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(results)
    print(f"\nResults written to {args.output}")

    # Summary
    counts = Counter(r['status'] for r in results)
    total_updates = counts.get('UPDATE', 0)
    print("\nSummary:")
    for status, count in sorted(counts.items()):
        print(f"  {status:<20} {count}")
    print(f"\n  {total_updates} folder ID(s) {'written to DB' if args.apply else 'ready to update (re-run with --apply)'}")

    cur.close()
    conn.close()


if __name__ == '__main__':
    main()
