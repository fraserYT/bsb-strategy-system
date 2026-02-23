-- BsB Strategy Planning System
-- Database Functions
-- Last updated: 2026-02-23

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
    -- Map Asana status values to database constraint values
    v_mapped_status := CASE p_status
        WHEN 'on_track' THEN 'on_track'
        WHEN 'at_risk' THEN 'at_risk'
        WHEN 'off_track' THEN 'blocked'
        WHEN 'on_hold' THEN 'on_hold'
        WHEN 'complete' THEN 'complete'
        ELSE 'not_started'
    END;

    -- Strip "2026 " prefix from focus cycle values (Asana stores "2026 FC1", DB stores "FC1")
    v_start_cycle := REPLACE(p_start_cycle, '2026 ', '');
    v_end_cycle := REPLACE(p_end_cycle, '2026 ', '');

    -- Upsert user first (only if owner exists)
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

    -- Upsert project
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
    -- Look up the parent project by its Asana ID
    SELECT id INTO v_project_id FROM projects WHERE asana_project_id = p_project_asana_id;

    -- Map completed boolean to status
    v_status := CASE WHEN p_completed THEN 'complete' ELSE 'upcoming' END;

    -- Upsert milestone and capture ID
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

    -- Sync strategic bet tags (if provided)
    IF p_strategic_bet_tags IS NOT NULL AND p_strategic_bet_tags != '' THEN
        -- Clear existing tags for this milestone
        DELETE FROM milestone_bet_tags WHERE milestone_id = v_milestone_id;

        -- Insert each tag (comma-separated from Asana multi-select)
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
-- Dates expected in DD/MM/YYYY format (UK Google Sheets locale)
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
    -- Parse submission_date (ISO format YYYY-MM-DD from Google Sheets via Gravity Forms)
    -- The sheet stores dates with a leading apostrophe (e.g. '2025-12-02) to force text format;
    -- Make.com receives the value without the apostrophe.
    BEGIN
        v_submission_date := CASE
            WHEN NULLIF(TRIM(p_submission_date), '') IS NULL THEN NULL
            ELSE TRIM(p_submission_date)::timestamptz
        END;
    EXCEPTION WHEN OTHERS THEN
        v_submission_date := NULL;
    END;

    -- Parse date_io_signed
    BEGIN
        v_date_io_signed := CASE
            WHEN NULLIF(TRIM(p_date_io_signed), '') IS NULL THEN NULL
            ELSE TRIM(p_date_io_signed)::timestamptz
        END;
    EXCEPTION WHEN OTHERS THEN
        v_date_io_signed := NULL;
    END;

    INSERT INTO insertion_orders (
        io_reference,
        salesperson_first_name,
        salesperson_last_name,
        salesperson_email,
        submission_date,
        date_io_signed,
        bsb_client_code,
        new_client,
        other_company,
        primary_contact_name,
        primary_contact_email,
        additional_contacts,
        salesperson_notes,
        product_type,
        signed_io_pdf_url,
        io_submission_permalink,
        company_name,
        formatted_company_name
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

    -- DO NOTHING means RETURNING yields NULL if record already existed — fetch existing id
    IF v_id IS NULL THEN
        SELECT id INTO v_id FROM insertion_orders WHERE io_reference = p_io_reference;
    END IF;

    RETURN v_id;
END;
$fn$ LANGUAGE plpgsql;


-- ============================================
-- update_insertion_order_links
-- Called by Make.com after the Asana task, Asana goal, and Drive folder have been created
-- Updates the three link fields on an existing insertion_orders record
-- Only overwrites a field if a non-empty value is provided (preserves existing if not)
-- goal_link is stored as a full URL; pass the raw GID from the Asana API response
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
