-- BsB Strategy Planning System
-- Database Functions
-- Last updated: 2026-02-24
--
-- Note on dollar-quoting: Sevalla SQL studio requires each function to be
-- pasted and run alone. New functions use single-quoted bodies to avoid
-- dollar-quoting issues entirely. Existing functions (upsert_project,
-- upsert_milestone) use $$ and are already deployed; re-deploy with $fn$
-- if Sevalla re-deployment is ever needed.

-- ============================================
-- upsert_project
-- Called by Make.com via PostgreSQL Execute Function module
-- Maps Asana project data into the projects table
-- ============================================

CREATE OR REPLACE FUNCTION upsert_project(
    p_asana_id TEXT,
    p_name TEXT,
    p_bet_code TEXT,
    p_team_name TEXT,
    p_owner_asana_id TEXT,
    p_owner_name TEXT,
    p_status TEXT,
    p_start_cycle TEXT,
    p_end_cycle TEXT,
    p_project_type TEXT
) RETURNS VOID AS $$
DECLARE
    v_user_id INTEGER;
    v_mapped_status TEXT;
    v_start_cycle TEXT;
    v_end_cycle TEXT;
BEGIN
    v_mapped_status := CASE p_status
        WHEN 'on_track' THEN 'on_track'
        WHEN 'at_risk' THEN 'at_risk'
        WHEN 'off_track' THEN 'blocked'
        WHEN 'on_hold' THEN 'on_hold'
        WHEN 'complete' THEN 'complete'
        ELSE 'not_started'
    END;

    v_start_cycle := REPLACE(p_start_cycle, '2026 ', '');
    v_end_cycle := REPLACE(p_end_cycle, '2026 ', '');

    IF p_owner_asana_id IS NOT NULL AND p_owner_asana_id != '' THEN
        INSERT INTO users (asana_user_id, first_name, last_name)
        VALUES (
            p_owner_asana_id,
            split_part(p_owner_name, ' ', 1),
            split_part(p_owner_name, ' ', 2)
        )
        ON CONFLICT (asana_user_id) DO UPDATE SET
            first_name = EXCLUDED.first_name,
            last_name = EXCLUDED.last_name,
            updated_at = NOW()
        RETURNING id INTO v_user_id;
    END IF;

    INSERT INTO projects (
        asana_project_id, code, name, strategic_bet_id, owning_department_id,
        project_lead, project_lead_id, status, start_cycle_id, end_cycle_id, project_type
    )
    VALUES (
        p_asana_id,
        'P-' || p_asana_id,
        p_name,
        (SELECT id FROM strategic_bets WHERE code = p_bet_code),
        (SELECT id FROM departments WHERE name = p_team_name),
        p_owner_name,
        v_user_id,
        v_mapped_status,
        (SELECT id FROM focus_cycles WHERE code = v_start_cycle),
        (SELECT id FROM focus_cycles WHERE code = v_end_cycle),
        p_project_type
    )
    ON CONFLICT (asana_project_id) DO UPDATE SET
        name = EXCLUDED.name,
        strategic_bet_id = EXCLUDED.strategic_bet_id,
        owning_department_id = EXCLUDED.owning_department_id,
        project_lead = EXCLUDED.project_lead,
        project_lead_id = EXCLUDED.project_lead_id,
        status = v_mapped_status,
        start_cycle_id = (SELECT id FROM focus_cycles WHERE code = v_start_cycle),
        end_cycle_id = (SELECT id FROM focus_cycles WHERE code = v_end_cycle),
        project_type = EXCLUDED.project_type,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- upsert_milestone
-- Called by Make.com via PostgreSQL Execute Function module
-- Maps Asana milestone data into the milestones table
-- 7th param (p_strategic_bet_tags) is optional for backwards compatibility
-- ============================================

CREATE OR REPLACE FUNCTION upsert_milestone(
    p_asana_id TEXT,
    p_project_asana_id TEXT,
    p_name TEXT,
    p_target_date DATE,
    p_completed BOOLEAN,
    p_focus_cycle TEXT,
    p_strategic_bet_tags TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_project_id INTEGER;
    v_milestone_id INTEGER;
    v_status TEXT;
    v_tag TEXT;
BEGIN
    SELECT id INTO v_project_id FROM projects WHERE asana_project_id = p_project_asana_id;

    v_status := CASE WHEN p_completed THEN 'complete' ELSE 'upcoming' END;

    INSERT INTO milestones (
        asana_milestone_id, code, project_id, name, target_date, status, focus_cycle_id
    )
    VALUES (
        p_asana_id,
        'M-' || p_asana_id,
        v_project_id,
        p_name,
        p_target_date,
        v_status,
        (SELECT id FROM focus_cycles WHERE code = REPLACE(p_focus_cycle, '2026 ', ''))
    )
    ON CONFLICT (asana_milestone_id) DO UPDATE SET
        name = EXCLUDED.name,
        target_date = EXCLUDED.target_date,
        status = v_status,
        focus_cycle_id = (SELECT id FROM focus_cycles WHERE code = REPLACE(p_focus_cycle, '2026 ', '')),
        updated_at = NOW()
    RETURNING id INTO v_milestone_id;

    IF p_strategic_bet_tags IS NOT NULL AND p_strategic_bet_tags != '' THEN
        DELETE FROM milestone_bet_tags WHERE milestone_id = v_milestone_id;

        FOREACH v_tag IN ARRAY string_to_array(p_strategic_bet_tags, ',')
        LOOP
            INSERT INTO milestone_bet_tags (milestone_id, strategic_bet_tag_id)
            SELECT v_milestone_id, sbt.id
            FROM strategic_bet_tags sbt
            WHERE sbt.name = TRIM(v_tag)
            ON CONFLICT (milestone_id, strategic_bet_tag_id) DO NOTHING;
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- upsert_insertion_order
-- Called by Make.com when a new IO submission is detected in Google Sheets
-- Inserts a new record; silently skips if io_reference already exists (DO NOTHING)
-- Returns the id of the inserted or existing record
-- Dates expected as ISO format YYYY-MM-DD (leading apostrophe stripped by Make.com)
-- new_client expected as "Yes"/"No" text from the sheet
-- ============================================

CREATE OR REPLACE FUNCTION upsert_insertion_order(
    p_io_reference              TEXT,
    p_salesperson_first_name    TEXT DEFAULT NULL,
    p_salesperson_last_name     TEXT DEFAULT NULL,
    p_salesperson_email         TEXT DEFAULT NULL,
    p_submission_date           TEXT DEFAULT NULL,
    p_date_io_signed            TEXT DEFAULT NULL,
    p_bsb_client_code           TEXT DEFAULT NULL,
    p_new_client                TEXT DEFAULT NULL,
    p_other_company             TEXT DEFAULT NULL,
    p_primary_contact_name      TEXT DEFAULT NULL,
    p_primary_contact_email     TEXT DEFAULT NULL,
    p_additional_contacts       TEXT DEFAULT NULL,
    p_salesperson_notes         TEXT DEFAULT NULL,
    p_product_type              TEXT DEFAULT NULL,
    p_signed_io_pdf_url         TEXT DEFAULT NULL,
    p_io_submission_permalink   TEXT DEFAULT NULL,
    p_company_name              TEXT DEFAULT NULL,
    p_formatted_company_name    TEXT DEFAULT NULL
) RETURNS INTEGER AS $fn$
DECLARE
    v_id                INTEGER;
    v_submission_date   TIMESTAMPTZ;
    v_date_io_signed    TIMESTAMPTZ;
BEGIN
    BEGIN
        v_submission_date := CASE
            WHEN NULLIF(TRIM(p_submission_date), '') IS NULL THEN NULL
            ELSE TRIM(p_submission_date)::timestamptz
        END;
    EXCEPTION WHEN OTHERS THEN
        v_submission_date := NULL;
    END;

    BEGIN
        v_date_io_signed := CASE
            WHEN NULLIF(TRIM(p_date_io_signed), '') IS NULL THEN NULL
            ELSE TRIM(p_date_io_signed)::timestamptz
        END;
    EXCEPTION WHEN OTHERS THEN
        v_date_io_signed := NULL;
    END;

    INSERT INTO insertion_orders (
        io_reference, salesperson_first_name, salesperson_last_name,
        salesperson_email, submission_date, date_io_signed, bsb_client_code,
        new_client, other_company, primary_contact_name, primary_contact_email,
        additional_contacts, salesperson_notes, product_type, signed_io_pdf_url,
        io_submission_permalink, company_name, formatted_company_name
    ) VALUES (
        p_io_reference,
        NULLIF(TRIM(p_salesperson_first_name), ''),
        NULLIF(TRIM(p_salesperson_last_name), ''),
        NULLIF(TRIM(p_salesperson_email), ''),
        v_submission_date,
        v_date_io_signed,
        NULLIF(TRIM(p_bsb_client_code), ''),
        CASE
            WHEN UPPER(TRIM(p_new_client)) IN ('YES', 'TRUE', '1') THEN TRUE
            WHEN UPPER(TRIM(p_new_client)) IN ('NO', 'FALSE', '0') THEN FALSE
            ELSE NULL
        END,
        NULLIF(TRIM(p_other_company), ''),
        NULLIF(TRIM(p_primary_contact_name), ''),
        NULLIF(TRIM(p_primary_contact_email), ''),
        NULLIF(TRIM(p_additional_contacts), ''),
        NULLIF(TRIM(p_salesperson_notes), ''),
        NULLIF(TRIM(p_product_type), ''),
        NULLIF(TRIM(p_signed_io_pdf_url), ''),
        NULLIF(TRIM(p_io_submission_permalink), ''),
        NULLIF(TRIM(p_company_name), ''),
        NULLIF(TRIM(p_formatted_company_name), '')
    )
    ON CONFLICT (io_reference) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        SELECT id INTO v_id FROM insertion_orders WHERE io_reference = p_io_reference;
    END IF;

    RETURN v_id;
END;
$fn$ LANGUAGE plpgsql;


-- ============================================
-- update_insertion_order_links
-- Called by Make.com after Asana task, Asana goal, and Drive folder are created
-- Updates the three link fields on an existing insertion_orders record
-- Only overwrites a field if a non-empty value is provided
-- goal_link stored as full URL; pass raw GID from Asana API response
-- ============================================

CREATE OR REPLACE FUNCTION update_insertion_order_links(
    p_io_reference  TEXT,
    p_asana_link    TEXT DEFAULT NULL,
    p_drive_link    TEXT DEFAULT NULL,
    p_goal_gid      TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $fn$
DECLARE
    v_rows INTEGER;
BEGIN
    UPDATE insertion_orders SET
        asana_link = COALESCE(NULLIF(TRIM(p_asana_link), ''), asana_link),
        drive_link = COALESCE(NULLIF(TRIM(p_drive_link), ''), drive_link),
        goal_link  = CASE
            WHEN NULLIF(TRIM(p_goal_gid), '') IS NOT NULL
            THEN 'https://app.asana.com/0/goal/' || TRIM(p_goal_gid)
            ELSE goal_link
        END
    WHERE io_reference = p_io_reference;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows > 0;
END;
$fn$ LANGUAGE plpgsql;


-- ============================================
-- get_client_folder_info
-- Called by Make.com at the start of the Drive folder creation flow.
-- Returns TLA, client name, contact name, and cached Tier 1+2 folder IDs.
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
-- update_client_folder_ids
-- Called by Make.com after creating Tier 1 and/or Tier 2 Drive folders.
-- Pass null/empty for a tier to leave it unchanged.
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
-- get_product_folder_info
-- Called by Make.com to look up Tier 3 (product type) and Tier 4 (year) folder IDs.
-- Tier 3: checks exact year first, falls back to any year for same product type.
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
-- upsert_product_folder
-- Called by Make.com after creating Tier 3 and/or Tier 4 Drive folders.
-- Inserts new row or updates existing for client + product type + year.
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


-- ============================================
-- upsert_client
-- Called by Make.com when New Client = Yes on IO form submission.
-- Creates or updates a client record (keyed on TLA).
-- Must be called before upsert_client_code.
-- Returns clients.id.
-- ============================================

CREATE OR REPLACE FUNCTION upsert_client(
    p_tla                   TEXT,
    p_client_name           TEXT,
    p_formatted_client_name TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS '
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO clients (tla, client_name, formatted_client_name)
    VALUES (
        UPPER(TRIM(p_tla)),
        TRIM(p_client_name),
        NULLIF(TRIM(p_formatted_client_name), '''')
    )
    ON CONFLICT (tla) DO UPDATE SET
        client_name           = EXCLUDED.client_name,
        formatted_client_name = COALESCE(EXCLUDED.formatted_client_name, clients.formatted_client_name)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
';


-- ============================================
-- upsert_client_code
-- Called by Make.com immediately after upsert_client when New Client = Yes.
-- Creates or updates a bsb_client_codes record.
-- Looks up client_id via TLA — upsert_client must run first.
-- Returns bsb_client_codes.id.
-- ============================================

CREATE OR REPLACE FUNCTION upsert_client_code(
    p_bsb_client_code       TEXT,
    p_tla                   TEXT,
    p_primary_contact       TEXT    DEFAULT NULL,
    p_primary_contact_email TEXT    DEFAULT NULL,
    p_payment_terms         TEXT    DEFAULT NULL,
    p_po_required           TEXT    DEFAULT NULL,
    p_billing_contact       TEXT    DEFAULT NULL,
    p_billing_email         TEXT    DEFAULT NULL,
    p_billing_address       TEXT    DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS '
DECLARE
    v_client_id INTEGER;
    v_id        INTEGER;
BEGIN
    SELECT id INTO v_client_id
    FROM clients
    WHERE tla = UPPER(TRIM(p_tla));

    INSERT INTO bsb_client_codes (
        bsb_client_code,
        client_id,
        primary_contact,
        primary_contact_email,
        payment_terms,
        po_required,
        client_billing_contact,
        client_billing_email,
        client_billing_address
    ) VALUES (
        UPPER(TRIM(p_bsb_client_code)),
        v_client_id,
        NULLIF(TRIM(p_primary_contact), ''''),
        NULLIF(TRIM(p_primary_contact_email), ''''),
        NULLIF(TRIM(p_payment_terms), ''''),
        NULLIF(TRIM(p_po_required), ''''),
        NULLIF(TRIM(p_billing_contact), ''''),
        NULLIF(TRIM(p_billing_email), ''''),
        NULLIF(TRIM(p_billing_address), '''')
    )
    ON CONFLICT (bsb_client_code) DO UPDATE SET
        client_id              = COALESCE(EXCLUDED.client_id, bsb_client_codes.client_id),
        primary_contact        = COALESCE(EXCLUDED.primary_contact, bsb_client_codes.primary_contact),
        primary_contact_email  = COALESCE(EXCLUDED.primary_contact_email, bsb_client_codes.primary_contact_email),
        payment_terms          = COALESCE(EXCLUDED.payment_terms, bsb_client_codes.payment_terms),
        po_required            = COALESCE(EXCLUDED.po_required, bsb_client_codes.po_required),
        client_billing_contact = COALESCE(EXCLUDED.client_billing_contact, bsb_client_codes.client_billing_contact),
        client_billing_email   = COALESCE(EXCLUDED.client_billing_email, bsb_client_codes.client_billing_email),
        client_billing_address = COALESCE(EXCLUDED.client_billing_address, bsb_client_codes.client_billing_address)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
';
