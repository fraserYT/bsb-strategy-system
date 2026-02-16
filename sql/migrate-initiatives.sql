-- BsB Strategy System
-- Migration: Strategic Bets → Initiatives + Milestone Tags
-- Date: 2026-02-16
-- Run on: Sevalla PostgreSQL (bitesize_bio database)
--
-- IMPORTANT: Run this as a single transaction. If any step fails, everything rolls back.

BEGIN;

-- ============================================
-- 1. Rename initiatives (keep table name as-is)
-- ============================================

UPDATE strategic_bets SET name = 'Build Mentor Machine', updated_at = NOW() WHERE code = 'B1';
UPDATE strategic_bets SET name = 'Standardise Sales and Marketing Processes', updated_at = NOW() WHERE code = 'B2';
UPDATE strategic_bets SET name = 'Automate Key Processes', updated_at = NOW() WHERE code = 'B3';
UPDATE strategic_bets SET name = 'Optimise Subscriber Growth Engine', updated_at = NOW() WHERE code = 'B4';

-- ============================================
-- 2. Add B5 initiative
-- ============================================

INSERT INTO strategic_bets (code, name) VALUES ('B5', 'Rebrand to reflect who we are now');

-- ============================================
-- 3. Create strategic bet tags lookup table
-- ============================================

CREATE TABLE strategic_bet_tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO strategic_bet_tags (name) VALUES
    ('Video-Led Mentor Content'),
    ('Informed Standardisation'),
    ('Capacity through Automation'),
    ('Owned Audience over SEO');

-- ============================================
-- 4. Create milestone ↔ bet tags junction table
-- ============================================

CREATE TABLE milestone_bet_tags (
    id SERIAL PRIMARY KEY,
    milestone_id INTEGER REFERENCES milestones(id) ON DELETE CASCADE,
    strategic_bet_tag_id INTEGER REFERENCES strategic_bet_tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (milestone_id, strategic_bet_tag_id)
);

CREATE INDEX idx_milestone_bet_tags_milestone ON milestone_bet_tags(milestone_id);
CREATE INDEX idx_milestone_bet_tags_tag ON milestone_bet_tags(strategic_bet_tag_id);

-- ============================================
-- 5. Update upsert_milestone function (7 params)
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
-- 6. Update v_milestone_timeline view
-- ============================================

DROP VIEW IF EXISTS v_milestone_timeline;

CREATE VIEW v_milestone_timeline AS
SELECT
    m.id,
    m.name as milestone_name,
    m.target_date,
    m.status,
    p.name as project_name,
    p.code as project_code,
    sb.code as initiative_code,
    sb.name as initiative_name,
    fc.code as cycle_code,
    d.name as dept_name,
    (
        SELECT STRING_AGG(sbt.name, ', ' ORDER BY sbt.name)
        FROM milestone_bet_tags mbt
        JOIN strategic_bet_tags sbt ON mbt.strategic_bet_tag_id = sbt.id
        WHERE mbt.milestone_id = m.id
    ) as strategic_bet_tags
FROM milestones m
    JOIN projects p ON m.project_id = p.id
    LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
    LEFT JOIN focus_cycles fc ON m.focus_cycle_id = fc.id
    LEFT JOIN departments d ON p.owning_department_id = d.id
ORDER BY m.target_date;

-- ============================================
-- 7. Create v_milestone_tags view
-- ============================================

CREATE VIEW v_milestone_tags AS
SELECT
    m.id as milestone_id,
    m.name as milestone_name,
    m.target_date,
    m.status as milestone_status,
    p.name as project_name,
    sb.code as initiative_code,
    sb.name as initiative_name,
    sbt.name as strategic_bet_tag,
    fc.code as cycle_code
FROM milestone_bet_tags mbt
    JOIN milestones m ON mbt.milestone_id = m.id
    JOIN strategic_bet_tags sbt ON mbt.strategic_bet_tag_id = sbt.id
    JOIN projects p ON m.project_id = p.id
    LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
    LEFT JOIN focus_cycles fc ON m.focus_cycle_id = fc.id
ORDER BY sbt.name, m.target_date;

COMMIT;
