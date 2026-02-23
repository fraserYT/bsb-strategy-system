-- Client migration step 2: clear existing data
-- CASCADE also truncates bsb_client_codes (FK dependency)
TRUNCATE clients CASCADE;
