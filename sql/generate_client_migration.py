#!/usr/bin/env python3
"""
Generate SQL migration for client directory reimport.

Reads:  temp/Client Directory List - Live Client List(1).csv
Writes: sql/migrate_clients.sql

Usage:
    python3 sql/generate_client_migration.py

Decisions applied:
  - LMS002 / ZEI003: extra annotation text in code field stripped to notes
  - po_required: changed from BOOLEAN to TEXT (column altered in migration)
  - SCA001 formatted name (10x Genomics / prev Scale Biosciences): imported as-is
  - mailto: prefix stripped from email fields
  - 'OTHER' placeholder row excluded
  - TLA derived from formatted_client_name brackets where present,
    otherwise stripped from trailing digits of client code
"""

import csv
import re
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CSV_PATH  = BASE_DIR / 'temp' / 'Client Directory List - Live Client List(1).csv'
OUT_PATH  = BASE_DIR / 'sql' / 'migrate_clients.sql'


def sql_val(value):
    """Return a SQL single-quoted string literal, or NULL.
    Internal newlines are collapsed to a space so the output stays single-line."""
    if value is None or str(value).strip() == '':
        return 'NULL'
    v = str(value).replace('\r\n', ' ').replace('\r', ' ').replace('\n', ' ')
    v = v.replace("'", "''")
    return f"'{v}'"


def clean(value):
    """Strip leading/trailing whitespace; return None if empty."""
    if not value:
        return None
    v = value.strip()
    return v or None


def clean_email(value):
    """Strip mailto: prefix and whitespace; return None if empty."""
    v = clean(value)
    if not v:
        return None
    if v.lower().startswith('mailto:'):
        v = v[7:].strip()
    return v or None


def tla_from_formatted(formatted):
    """
    Extract TLA from formatted client name.
    Takes the LAST bracketed value — e.g.:
      'Arralyze [ARR]'                                     → ARR
      '10x Genomics [10x] (( prev. Scale Biosciences [SCA] ))' → SCA
    """
    if not formatted:
        return None
    matches = re.findall(r'\[([A-Za-z0-9]+)\]', formatted)
    return matches[-1] if matches else None


def tla_from_code(code):
    """Strip trailing digits from a client code: 'BTN002' → 'BTN'."""
    return re.sub(r'\d+$', '', code.strip())


# ── Read CSV ──────────────────────────────────────────────────────────────────

rows = []
with open(CSV_PATH, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        raw_code = row['BsB Client Code'].strip()

        # Skip placeholder row
        if raw_code.upper().startswith('OTHER'):
            continue

        # Handle codes with embedded annotation (LMS002, ZEI003)
        annotation = None
        if '\n' in raw_code:
            parts = raw_code.split('\n', 1)
            code = parts[0].strip()
            annotation = parts[1].strip().strip('()').strip() or None
        else:
            code = raw_code

        # Merge annotation into notes
        notes = clean(row['Notes'])
        if annotation:
            notes = f"{annotation}. {notes}" if notes else annotation

        formatted = clean(row['Formatted Client Name'])
        tla = tla_from_formatted(formatted) or tla_from_code(code)

        rows.append({
            'code':          code,
            'tla':           tla,
            'client_name':   clean(row['Client Name']),
            'primary_contact':       clean(row['Primary contact']),
            'primary_contact_email': clean_email(row['Primary Contact Email']),
            'other_people':          clean(row['Other People in this Client Code']),
            'payment_terms':         clean(row['Payment Terms']),
            'po_required':           clean(row['PO Required?']),
            'billing_contact':       clean(row['Client Billing contact']),
            'billing_email':         clean_email(row['Client Billing email']),
            'billing_address':       clean(row['Client Billing Address']),
            'notes':                 notes,
            'formatted_client_name': formatted,
        })

# ── Unique companies (first occurrence of each TLA wins) ──────────────────────

companies = {}
for r in rows:
    if r['tla'] not in companies:
        companies[r['tla']] = {
            'client_name':          r['client_name'],
            'formatted_client_name': r['formatted_client_name'],
            'tla':                  r['tla'],
        }

# ── Build SQL — four separate files (Sevalla doesn't support multi-statement) ──

SQL_DIR = BASE_DIR / 'sql' / 'client_migration'
SQL_DIR.mkdir(exist_ok=True)

# Step 1 — schema changes (two ALTER statements, run separately)
step1a = (
    '-- Client migration step 1a: add tla column to clients\n'
    'ALTER TABLE clients\n'
    '    ADD COLUMN IF NOT EXISTS tla VARCHAR(20);\n'
)
step1b = (
    '-- Client migration step 1b: change po_required to TEXT\n'
    '-- Preserves full values e.g. "Yes (Coupa)", "No - but check for next order"\n'
    'ALTER TABLE bsb_client_codes\n'
    '    ALTER COLUMN po_required TYPE TEXT USING po_required::TEXT;\n'
)

# Step 2 — clear existing data
step2 = (
    '-- Client migration step 2: clear existing data\n'
    '-- CASCADE also truncates bsb_client_codes (FK dependency)\n'
    'TRUNCATE clients CASCADE;\n'
)

# Step 3 — insert unique companies
company_vals = []
for tla in sorted(companies.keys()):
    c = companies[tla]
    company_vals.append(
        f"  ({sql_val(c['client_name'])}, "
        f"{sql_val(c['formatted_client_name'])}, "
        f"{sql_val(c['tla'])})"
    )
step3 = (
    f'-- Client migration step 3: insert {len(companies)} unique companies\n'
    'INSERT INTO clients (client_name, formatted_client_name, tla) VALUES\n'
    + ',\n'.join(company_vals) + ';\n'
)

# Step 4 — insert client codes (client_id resolved via TLA JOIN)
code_vals = []
for r in rows:
    code_vals.append(
        f"    ({sql_val(r['code'])}, {sql_val(r['tla'])}, "
        f"{sql_val(r['primary_contact'])}, {sql_val(r['primary_contact_email'])}, "
        f"{sql_val(r['other_people'])}, {sql_val(r['payment_terms'])}, "
        f"{sql_val(r['po_required'])}, {sql_val(r['billing_contact'])}, "
        f"{sql_val(r['billing_email'])}, {sql_val(r['billing_address'])}, "
        f"{sql_val(r['notes'])})"
    )
step4 = (
    f'-- Client migration step 4: insert {len(rows)} client codes\n'
    'INSERT INTO bsb_client_codes (\n'
    '    bsb_client_code, client_id,\n'
    '    primary_contact, primary_contact_email,\n'
    '    other_people_in_client_code, payment_terms, po_required,\n'
    '    client_billing_contact, client_billing_email, client_billing_address, notes\n'
    ')\n'
    'SELECT\n'
    '    v.bsb_client_code, c.id,\n'
    '    v.primary_contact, v.primary_contact_email,\n'
    '    v.other_people, v.payment_terms, v.po_required,\n'
    '    v.billing_contact, v.billing_email, v.billing_address, v.notes\n'
    'FROM (VALUES\n'
    + ',\n'.join(code_vals) + '\n'
    ') AS v(\n'
    '    bsb_client_code, tla,\n'
    '    primary_contact, primary_contact_email,\n'
    '    other_people, payment_terms, po_required,\n'
    '    billing_contact, billing_email, billing_address, notes\n'
    ')\n'
    'JOIN clients c ON c.tla = v.tla;\n'
)

steps = [
    ('1a_schema_clients.sql',    step1a),
    ('1b_schema_po_required.sql', step1b),
    ('2_truncate.sql',            step2),
    ('3_insert_companies.sql',    step3),
    ('4_insert_codes.sql',        step4),
]

for filename, sql in steps:
    path = SQL_DIR / filename
    path.write_text(sql, encoding='utf-8')
    print(f"✓ {path.relative_to(BASE_DIR)}")

print(f"\nRun in order: 1a → 1b → 2 → 3 → 4")
print(f"  Companies:   {len(companies)}")
print(f"  Client codes: {len(rows)}")
