-- Client migration step 1a: add tla column to clients
ALTER TABLE clients
    ADD COLUMN IF NOT EXISTS tla VARCHAR(20);
