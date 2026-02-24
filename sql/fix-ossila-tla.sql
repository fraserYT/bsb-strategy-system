-- Fix Ossila TLA: OOS → OSS
-- OSS is the correct TLA (OOS was a typo on the spreadsheet).
-- Run on Sevalla PostgreSQL. Paste and run as a single block.
-- Last updated: 2026-02-24

UPDATE clients
    SET tla = 'OSS'
    WHERE tla = 'OOS';

UPDATE bsb_client_codes
    SET bsb_client_code = REPLACE(bsb_client_code, 'OOS', 'OSS')
    WHERE bsb_client_code LIKE 'OOS%';

-- Also fix any existing insertion_orders rows that reference the old code
UPDATE insertion_orders
    SET bsb_client_code = REPLACE(bsb_client_code, 'OOS', 'OSS')
    WHERE bsb_client_code LIKE 'OOS%';
