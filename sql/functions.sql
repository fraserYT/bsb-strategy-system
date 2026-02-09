-- BsB Strategy Planning System
-- Database Functions
-- Last updated: 2026-02-02

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
BEGIN
    -- Upsert user first
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

-- Upsert project
INSERT INTO projects (
    asana_project_id,
    code,
    name,
    strategic_bet_id,
    owning_department_id,
    project_lead,
    project_lead_id,
    status,
    start_cycle_id,
    end_cycle_id
)
VALUES (
           p_asana_id,
           'P-' || p_asana_id,
           p_name,
           (SELECT id FROM strategic_bets WHERE code = p_bet_code),
           (SELECT id FROM departments WHERE name = p_team_name),
           p_owner_name,
           v_user_id,
           p_status,
           (SELECT id FROM focus_cycles WHERE code = p_start_cycle),
           (SELECT id FROM focus_cycles WHERE code = p_end_cycle)
       )
    ON CONFLICT (asana_project_id)
    DO UPDATE SET
    name = EXCLUDED.name,
               owning_department_id = EXCLUDED.owning_department_id,
               project_lead = EXCLUDED.project_lead,
               project_lead_id = EXCLUDED.project_lead_id,
               status = EXCLUDED.status,
               start_cycle_id = EXCLUDED.start_cycle_id,
               end_cycle_id = EXCLUDED.end_cycle_id,
               updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
