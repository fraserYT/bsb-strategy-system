-- BsB Strategy Planning System
-- Database Functions
-- Last updated: 2026-02-16

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
