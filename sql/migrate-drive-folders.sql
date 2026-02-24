-- Drive Folder Structure Migration
-- Run on Sevalla PostgreSQL (bitesize_bio database)
-- Adds Drive folder ID caching for the 4-tier client folder hierarchy
--
-- IMPORTANT: Sevalla SQL studio runs the entire editor content as one batch.
-- Paste the schema block (steps 1-4) first, then each function separately.
-- Functions use single-quoted bodies to avoid all dollar-quoting issues.
-- Last updated: 2026-02-24


-- ============================================
-- STEPS 1-4: Schema changes
-- Paste and run this block first.
-- ============================================

ALTER TABLE clients
    ADD COLUMN IF NOT EXISTS drive_folder_id TEXT;

ALTER TABLE bsb_client_codes
    ADD COLUMN IF NOT EXISTS drive_folder_id TEXT;

CREATE TABLE IF NOT EXISTS client_product_folders (
    id                      SERIAL PRIMARY KEY,
    client_code_id          INTEGER NOT NULL REFERENCES bsb_client_codes(id),
    product_type            TEXT NOT NULL,
    product_type_folder_id  TEXT,
    year                    INTEGER NOT NULL,
    year_folder_id          TEXT NOT NULL,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (client_code_id, product_type, year)
);

CREATE INDEX IF NOT EXISTS idx_client_product_folders_code
    ON client_product_folders(client_code_id);


-- ============================================
-- STEP 5: get_client_folder_info
-- Paste and run this block alone.
-- Returns TLA, names, and cached Tier 1+2 folder IDs for a given client code.
-- Null folder IDs = folders don't exist yet and need creating in Drive.
-- Root "Client Projects" folder ID: 1PURGWZSK1gMTJN7GDYogY1Q0_ohsUkht
-- ============================================

CREATE OR REPLACE FUNCTION get_client_folder_info(p_client_code TEXT)
RETURNS TABLE (
    tla                 TEXT,
    client_name         TEXT,
    primary_contact     TEXT,
    tier1_folder_id     TEXT,
    tier2_folder_id     TEXT
)
LANGUAGE plpgsql
AS '
BEGIN
    RETURN QUERY
    SELECT
        c.tla::TEXT,
        c.client_name::TEXT,
        cc.primary_contact::TEXT,
        c.drive_folder_id::TEXT,
        cc.drive_folder_id::TEXT
    FROM bsb_client_codes cc
    JOIN clients c ON cc.client_id = c.id
    WHERE cc.bsb_client_code = TRIM(p_client_code);
END;
';


-- ============================================
-- STEP 6: update_client_folder_ids
-- Paste and run this block alone.
-- Stores Tier 1 and/or Tier 2 Drive folder IDs after creation.
-- Pass empty string for a tier to leave it unchanged.
-- ============================================

CREATE OR REPLACE FUNCTION update_client_folder_ids(
    p_client_code       TEXT,
    p_tier1_folder_id   TEXT DEFAULT NULL,
    p_tier2_folder_id   TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS '
DECLARE
    v_client_id INTEGER;
BEGIN
    SELECT c.id INTO v_client_id
    FROM bsb_client_codes cc
    JOIN clients c ON cc.client_id = c.id
    WHERE cc.bsb_client_code = TRIM(p_client_code);

    IF v_client_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF NULLIF(TRIM(p_tier1_folder_id), '''') IS NOT NULL THEN
        UPDATE clients
        SET drive_folder_id = TRIM(p_tier1_folder_id)
        WHERE id = v_client_id;
    END IF;

    IF NULLIF(TRIM(p_tier2_folder_id), '''') IS NOT NULL THEN
        UPDATE bsb_client_codes
        SET drive_folder_id = TRIM(p_tier2_folder_id)
        WHERE bsb_client_code = TRIM(p_client_code);
    END IF;

    RETURN TRUE;
END;
';


-- ============================================
-- STEP 7: get_product_folder_info
-- Paste and run this block alone.
-- Returns Tier 3 (product type) and Tier 4 (year) folder IDs.
-- Tier 3: exact year match first, falls back to any year for same product type.
-- Tier 4: exact match only. Null = needs creating.
-- ============================================

CREATE OR REPLACE FUNCTION get_product_folder_info(
    p_client_code   TEXT,
    p_product_type  TEXT,
    p_year          INTEGER
)
RETURNS TABLE (
    product_type_folder_id  TEXT,
    year_folder_id          TEXT
)
LANGUAGE plpgsql
AS '
DECLARE
    v_client_code_id        INTEGER;
    v_product_type_folder   TEXT;
    v_year_folder           TEXT;
BEGIN
    SELECT cc.id INTO v_client_code_id
    FROM bsb_client_codes cc
    WHERE cc.bsb_client_code = TRIM(p_client_code);

    SELECT cpf.product_type_folder_id INTO v_product_type_folder
    FROM client_product_folders cpf
    WHERE cpf.client_code_id = v_client_code_id
      AND cpf.product_type = TRIM(p_product_type)
      AND cpf.year = p_year
    LIMIT 1;

    IF v_product_type_folder IS NULL THEN
        SELECT cpf.product_type_folder_id INTO v_product_type_folder
        FROM client_product_folders cpf
        WHERE cpf.client_code_id = v_client_code_id
          AND cpf.product_type = TRIM(p_product_type)
          AND cpf.product_type_folder_id IS NOT NULL
        LIMIT 1;
    END IF;

    SELECT cpf.year_folder_id INTO v_year_folder
    FROM client_product_folders cpf
    WHERE cpf.client_code_id = v_client_code_id
      AND cpf.product_type = TRIM(p_product_type)
      AND cpf.year = p_year
    LIMIT 1;

    RETURN QUERY SELECT v_product_type_folder, v_year_folder;
END;
';


-- ============================================
-- STEP 8: upsert_product_folder
-- Paste and run this block alone.
-- Stores Tier 3+4 folder IDs after creation in Drive.
-- Returns client_product_folders row id.
-- ============================================

CREATE OR REPLACE FUNCTION upsert_product_folder(
    p_client_code               TEXT,
    p_product_type              TEXT,
    p_year                      INTEGER,
    p_product_type_folder_id    TEXT,
    p_year_folder_id            TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS '
DECLARE
    v_client_code_id    INTEGER;
    v_id                INTEGER;
BEGIN
    SELECT cc.id INTO v_client_code_id
    FROM bsb_client_codes cc
    WHERE cc.bsb_client_code = TRIM(p_client_code);

    IF v_client_code_id IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO client_product_folders (
        client_code_id, product_type, product_type_folder_id, year, year_folder_id
    ) VALUES (
        v_client_code_id,
        TRIM(p_product_type),
        NULLIF(TRIM(p_product_type_folder_id), ''''),
        p_year,
        TRIM(p_year_folder_id)
    )
    ON CONFLICT (client_code_id, product_type, year) DO UPDATE SET
        product_type_folder_id = COALESCE(
            NULLIF(TRIM(p_product_type_folder_id), ''''),
            client_product_folders.product_type_folder_id
        ),
        year_folder_id = TRIM(p_year_folder_id)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
';
