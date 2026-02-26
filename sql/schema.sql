-- BsB Strategy Planning System
-- Database Schema
-- Last updated: 2026-02-24

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE strategic_bets (
                                id SERIAL PRIMARY KEY,
                                code VARCHAR(10) UNIQUE NOT NULL,
                                name VARCHAR(255) NOT NULL,
                                target_outcome TEXT,
                                created_at TIMESTAMP DEFAULT NOW(),
                                updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE focus_cycles (
                              id SERIAL PRIMARY KEY,
                              code VARCHAR(10) UNIQUE NOT NULL,
                              name VARCHAR(100) NOT NULL,
                              start_date DATE NOT NULL,
                              end_date DATE NOT NULL,
                              status VARCHAR(20) DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'complete')),
                              created_at TIMESTAMP DEFAULT NOW(),
                              updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE departments (
                             id SERIAL PRIMARY KEY,
                             code VARCHAR(10) UNIQUE NOT NULL,
                             name VARCHAR(100) NOT NULL,
                             created_at TIMESTAMP DEFAULT NOW(),
                             updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE users (
                       id SERIAL PRIMARY KEY,
                       asana_user_id TEXT UNIQUE NOT NULL,
                       first_name TEXT,
                       last_name TEXT,
                       email TEXT,
                       department_id INTEGER REFERENCES departments(id),
                       is_active BOOLEAN DEFAULT true,
                       created_at TIMESTAMP DEFAULT NOW(),
                       updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE projects (
                          id SERIAL PRIMARY KEY,
                          asana_project_id TEXT UNIQUE,
                          code VARCHAR(50) UNIQUE NOT NULL,
                          name VARCHAR(255) NOT NULL,
                          strategic_bet_id INTEGER REFERENCES strategic_bets(id),
                          owning_department_id INTEGER REFERENCES departments(id),
                          project_lead TEXT,
                          project_lead_id INTEGER REFERENCES users(id),
                          status VARCHAR(20) DEFAULT 'not_started'
                              CHECK (status IN ('not_started', 'on_track', 'at_risk', 'blocked', 'on_hold', 'complete', 'cancelled')),
                          percent_complete DECIMAL(5,2) DEFAULT 0,
                          start_cycle_id INTEGER REFERENCES focus_cycles(id),
                          end_cycle_id INTEGER REFERENCES focus_cycles(id),
                          project_type TEXT,
                          created_at TIMESTAMP DEFAULT NOW(),
                          updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE milestones (
                            id SERIAL PRIMARY KEY,
                            asana_milestone_id TEXT UNIQUE,
                            code VARCHAR(50) NOT NULL,
                            project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
                            name VARCHAR(255) NOT NULL,
                            target_date DATE,
                            status VARCHAR(20) DEFAULT 'upcoming'
                                CHECK (status IN ('upcoming', 'in_progress', 'complete', 'blocked', 'cancelled')),
                            focus_cycle_id INTEGER REFERENCES focus_cycles(id),
                            tasks_total INTEGER DEFAULT 0,
                            tasks_complete INTEGER DEFAULT 0,
                            created_at TIMESTAMP DEFAULT NOW(),
                            updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE strategy_milestones (
                                     id SERIAL PRIMARY KEY,
                                     strategic_bet_id INTEGER REFERENCES strategic_bets(id),
                                     name VARCHAR(255) NOT NULL,
                                     description TEXT,
                                     target_quarter VARCHAR(10),
                                     status VARCHAR(20) DEFAULT 'not_started'
                                         CHECK (status IN ('not_started', 'in_progress', 'complete', 'missed')),
                                     evidence TEXT,
                                     created_at TIMESTAMP DEFAULT NOW(),
                                     updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE proposals (
                           id SERIAL PRIMARY KEY,
                           asana_task_id TEXT UNIQUE,
                           title VARCHAR(255) NOT NULL,
                           proposed_department_id INTEGER REFERENCES departments(id),
                           strategic_bet_id INTEGER REFERENCES strategic_bets(id),
                           estimated_size VARCHAR(20) CHECK (estimated_size IN ('small', 'medium', 'large')),
                           proposed_start_quarter VARCHAR(10),
                           status VARCHAR(20) DEFAULT 'submitted'
                               CHECK (status IN ('submitted', 'under_review', 'approved', 'rejected', 'deferred')),
                           reviewer1_id INTEGER REFERENCES users(id),
                           reviewer1_decision VARCHAR(20),
                           reviewer2_id INTEGER REFERENCES users(id),
                           reviewer2_decision VARCHAR(20),
                           created_at TIMESTAMP DEFAULT NOW(),
                           updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE progress_snapshots (
                                    id SERIAL PRIMARY KEY,
                                    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
                                    snapshot_date DATE NOT NULL,
                                    percent_complete DECIMAL(5,2),
                                    status VARCHAR(20),
                                    notes TEXT,
                                    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE strategic_bet_tags (
                                    id SERIAL PRIMARY KEY,
                                    name VARCHAR(255) UNIQUE NOT NULL,
                                    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE milestone_bet_tags (
                                    id SERIAL PRIMARY KEY,
                                    milestone_id INTEGER REFERENCES milestones(id) ON DELETE CASCADE,
                                    strategic_bet_tag_id INTEGER REFERENCES strategic_bet_tags(id) ON DELETE CASCADE,
                                    created_at TIMESTAMP DEFAULT NOW(),
                                    UNIQUE (milestone_id, strategic_bet_tag_id)
);

-- ============================================
-- CLIENT & IO TABLES
-- (business operations data, separate from strategy/planning tables above)
-- ============================================

-- Master client list
CREATE TABLE clients (
    id                      SERIAL PRIMARY KEY,
    client_name             VARCHAR(255) NOT NULL,
    formatted_client_name   VARCHAR(255),
    tla                     VARCHAR(20),
    drive_folder_id         TEXT,           -- Tier 1: "[TLA] Client Name" folder in Client Projects
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

-- One or more client codes per client (different subsidiaries, departments, etc.)
-- Contains billing and contact details per code
CREATE TABLE bsb_client_codes (
    id                          SERIAL PRIMARY KEY,
    bsb_client_code             VARCHAR(50) UNIQUE NOT NULL,
    client_id                   INTEGER REFERENCES clients(id),
    primary_contact             VARCHAR(255),
    primary_contact_email       VARCHAR(255),
    other_people_in_client_code TEXT,
    payment_terms               VARCHAR(100),
    po_required                 TEXT,
    client_billing_contact      VARCHAR(255),
    client_billing_email        VARCHAR(255),
    client_billing_address      TEXT,
    notes                       TEXT,
    drive_folder_id             TEXT,       -- Tier 2: "[CODE] Contact Name" folder inside Tier 1
    created_at                  TIMESTAMPTZ DEFAULT NOW()
);

-- Drive folder ID cache for Tiers 3+4 of the client folder hierarchy
-- Tier 3: "[CODE] Product Type" folder (e.g. "[LMS001] Live Events")
-- Tier 4: "YYYY" year folder inside Tier 3 (year derived from IO signed date)
-- One row per unique client code + product type + year combination
CREATE TABLE client_product_folders (
    id                      SERIAL PRIMARY KEY,
    client_code_id          INTEGER NOT NULL REFERENCES bsb_client_codes(id),
    product_type            TEXT NOT NULL,
    product_type_folder_id  TEXT,           -- Tier 3 folder ID (shared across years)
    year                    INTEGER NOT NULL,
    year_folder_id          TEXT NOT NULL,  -- Tier 4 folder ID (specific to year)
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (client_code_id, product_type, year)
);

-- Insertion Orders — populated by Make.com on new IO form submission
-- bsb_client_code is a loose text reference (not FK) — new clients may not have a code yet
-- asana_link, drive_link, goal_link are populated by a separate Make.com step after creation
CREATE TABLE insertion_orders (
    id                          SERIAL PRIMARY KEY,
    io_reference                VARCHAR(255) UNIQUE NOT NULL,
    salesperson_first_name      VARCHAR(255),
    salesperson_last_name       VARCHAR(255),
    salesperson_email           VARCHAR(255),
    submission_date             TIMESTAMPTZ,
    date_io_signed              TIMESTAMPTZ,
    bsb_client_code             VARCHAR(50),
    new_client                  BOOLEAN,
    other_company               TEXT,
    primary_contact_name        VARCHAR(255),
    primary_contact_email       VARCHAR(255),
    additional_contacts         TEXT,
    salesperson_notes           TEXT,
    product_type                VARCHAR(255),
    signed_io_pdf_url           TEXT,
    io_submission_permalink     TEXT,
    company_name                VARCHAR(255),
    formatted_company_name      VARCHAR(255),
    asana_link                  TEXT,
    metabase_link               TEXT,
    goal_link                   TEXT,
    created_at                  TIMESTAMPTZ DEFAULT NOW()
);

-- IO Products — one record per product per IO submission
-- unique_id is the EVENT-{IO Ref}-{UUID} generated by Make.com
-- asana_project_id is nullable; populated when per-product Asana creation is built
CREATE TABLE io_products (
    id                  SERIAL PRIMARY KEY,
    io_reference        VARCHAR(255) NOT NULL,  -- loose ref to insertion_orders; no FK to avoid type mismatch
    product_type        TEXT NOT NULL,
    product_name        TEXT,
    unique_id           TEXT UNIQUE NOT NULL,
    drive_folder_id     TEXT,
    asana_project_id    TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Daily team check-in responses (anonymous — no user_id stored by design)
-- See also: sql/checkin-schema.sql for views and insert function
CREATE TABLE checkin_responses (
    id              SERIAL PRIMARY KEY,
    response_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    mood_rating     SMALLINT NOT NULL CHECK (mood_rating BETWEEN 1 AND 10),
    busyness_rating SMALLINT NOT NULL CHECK (busyness_rating BETWEEN 1 AND 10),
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_projects_bet ON projects(strategic_bet_id);
CREATE INDEX idx_projects_dept ON projects(owning_department_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_milestones_project ON milestones(project_id);
CREATE INDEX idx_milestones_cycle ON milestones(focus_cycle_id);
CREATE INDEX idx_users_asana_id ON users(asana_user_id);
CREATE INDEX idx_milestone_bet_tags_milestone ON milestone_bet_tags(milestone_id);
CREATE INDEX idx_milestone_bet_tags_tag ON milestone_bet_tags(strategic_bet_tag_id);
CREATE INDEX idx_client_product_folders_code ON client_product_folders(client_code_id);
CREATE INDEX idx_io_products_io_reference ON io_products(io_reference);

-- ============================================
-- VIEWS
-- ============================================

CREATE VIEW v_executive_summary AS
SELECT
    (SELECT COUNT(*) FROM projects WHERE status NOT IN ('cancelled')) as total_projects,
    (SELECT COUNT(*) FROM projects WHERE status = 'on_track') as on_track,
    (SELECT COUNT(*) FROM projects WHERE status = 'at_risk') as at_risk,
    (SELECT COUNT(*) FROM projects WHERE status = 'blocked') as blocked,
    (SELECT COUNT(*) FROM projects WHERE status = 'on_hold') as on_hold,
    (SELECT COUNT(*) FROM projects WHERE status = 'not_started') as not_started,
    (SELECT COUNT(*) FROM projects WHERE status = 'complete') as complete,
    (SELECT ROUND(AVG(percent_complete), 1) FROM projects WHERE status NOT IN ('cancelled', 'on_hold')) as avg_completion,
    (SELECT code FROM focus_cycles WHERE status = 'active' LIMIT 1) as current_cycle;

CREATE VIEW v_bet_health AS
SELECT
    sb.id,
    sb.code,
    sb.name,
    sb.target_outcome,
    COUNT(p.id) as project_count,
    ROUND(AVG(p.percent_complete), 1) as avg_completion,
    SUM(CASE WHEN p.status = 'on_track' THEN 1 ELSE 0 END) as on_track_count,
    SUM(CASE WHEN p.status = 'at_risk' THEN 1 ELSE 0 END) as at_risk_count,
    SUM(CASE WHEN p.status = 'blocked' THEN 1 ELSE 0 END) as blocked_count,
    SUM(CASE WHEN p.status = 'on_hold' THEN 1 ELSE 0 END) as on_hold_count,
    (SELECT COUNT(*) FROM strategy_milestones sm WHERE sm.strategic_bet_id = sb.id AND sm.status = 'complete') as strategy_milestones_complete,
    (SELECT COUNT(*) FROM strategy_milestones sm WHERE sm.strategic_bet_id = sb.id) as strategy_milestones_total
FROM strategic_bets sb
         LEFT JOIN projects p ON p.strategic_bet_id = sb.id AND p.status != 'cancelled'
GROUP BY sb.id, sb.code, sb.name, sb.target_outcome
ORDER BY sb.code;

CREATE VIEW v_department_workload AS
SELECT
    d.id as dept_id,
    d.code as dept_code,
    d.name as dept_name,
    COUNT(DISTINCT p.id) as project_count,
    SUM(CASE WHEN p.status = 'on_track' THEN 1 ELSE 0 END) as on_track,
    SUM(CASE WHEN p.status IN ('at_risk', 'blocked') THEN 1 ELSE 0 END) as needs_attention,
    SUM(CASE WHEN p.status = 'on_hold' THEN 1 ELSE 0 END) as on_hold,
    ROUND(AVG(p.percent_complete), 1) as avg_completion,
    COUNT(DISTINCT m.id) FILTER (WHERE m.status = 'in_progress') as active_milestones
FROM departments d
         LEFT JOIN projects p ON p.owning_department_id = d.id AND p.status NOT IN ('cancelled', 'complete')
         LEFT JOIN milestones m ON m.project_id = p.id
GROUP BY d.id, d.code, d.name
ORDER BY d.code;

CREATE VIEW v_cycle_progress AS
SELECT
    fc.id,
    fc.code,
    fc.name,
    fc.start_date,
    fc.end_date,
    fc.status,
    COUNT(DISTINCT m.id) as total_milestones,
    COUNT(DISTINCT m.id) FILTER (WHERE m.status = 'complete') as complete_milestones,
    COUNT(DISTINCT m.id) FILTER (WHERE m.status = 'missed') as missed_milestones
FROM focus_cycles fc
         LEFT JOIN milestones m ON m.focus_cycle_id = fc.id
GROUP BY fc.id, fc.code, fc.name, fc.start_date, fc.end_date, fc.status
ORDER BY fc.start_date;

CREATE VIEW v_project_detail AS
SELECT
    p.id,
    p.code,
    p.name,
    p.status,
    p.percent_complete,
    sb.code as bet_code,
    sb.name as bet_name,
    d.code as dept_code,
    d.name as dept_name,
    p.project_lead,
    fc_start.code as start_cycle,
    fc_end.code as end_cycle,
    COUNT(m.id) as milestone_count,
    COUNT(m.id) FILTER (WHERE m.status = 'complete') as milestones_complete
FROM projects p
         LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
         LEFT JOIN departments d ON p.owning_department_id = d.id
         LEFT JOIN focus_cycles fc_start ON p.start_cycle_id = fc_start.id
         LEFT JOIN focus_cycles fc_end ON p.end_cycle_id = fc_end.id
         LEFT JOIN milestones m ON m.project_id = p.id
GROUP BY p.id, p.code, p.name, p.status, p.percent_complete,
         sb.code, sb.name, d.code, d.name, p.project_lead,
         fc_start.code, fc_end.code;

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

CREATE VIEW v_at_risk_projects AS
SELECT
    p.id,
    p.code,
    p.name,
    p.status,
    p.percent_complete,
    sb.name as bet_name,
    d.name as dept_name,
    p.project_lead,
    p.updated_at as last_updated
FROM projects p
         LEFT JOIN strategic_bets sb ON p.strategic_bet_id = sb.id
         LEFT JOIN departments d ON p.owning_department_id = d.id
WHERE p.status IN ('at_risk', 'blocked')
ORDER BY p.status, p.updated_at;

-- ============================================
-- SEED DATA
-- ============================================

INSERT INTO strategic_bets (code, name) VALUES
                                            ('B1', 'Build Mentor Machine'),
                                            ('B2', 'Standardise Sales and Marketing Processes'),
                                            ('B3', 'Automate Key Processes'),
                                            ('B4', 'Optimise Subscriber Growth Engine'),
                                            ('B5', 'Rebrand to reflect who we are now');

INSERT INTO strategic_bet_tags (name) VALUES
                                          ('Video-Led Mentor Content'),
                                          ('Informed Standardisation'),
                                          ('Capacity through Automation'),
                                          ('Owned Audience over SEO');

INSERT INTO focus_cycles (code, name, start_date, end_date, status) VALUES
                                                                        ('FC1', '2026 Cycle 1', '2026-02-23', '2026-04-05', 'upcoming'),
                                                                        ('FC2', '2026 Cycle 2', '2026-04-13', '2026-05-24', 'upcoming'),
                                                                        ('FC3', '2026 Cycle 3', '2026-06-01', '2026-07-12', 'upcoming'),
                                                                        ('FC4', '2026 Cycle 4', '2026-07-20', '2026-08-30', 'upcoming'),
                                                                        ('FC5', '2026 Cycle 5', '2026-09-07', '2026-10-18', 'upcoming'),
                                                                        ('FC6', '2026 Cycle 6', '2026-10-26', '2026-12-06', 'upcoming');

INSERT INTO departments (code, name) VALUES
                                         ('PROD', 'Production'),
                                         ('EDIT', 'Editorial'),
                                         ('DEV', 'Development'),
                                         ('INFRA', 'Infrastructure'),
                                         ('WFS', 'Workflow Support'),
                                         ('MKT', 'Marketing'),
                                         ('SAL', 'Sales'),
                                         ('BOARD', 'Board'),
                                         ('STRAT', 'Strategy'),
                                         ('DES', 'Design');
