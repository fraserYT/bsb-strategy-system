# Session Log

## 2026-01-30

- Set up PostgreSQL database on Sevalla
- Created schema (8 tables)
- Added dummy data
- Created indexes and views
- Set up Metabase on Sevalla
- Built executive dashboard (8 cards)

## 2026-02-02

- Updated departments to actual teams (10)
- Updated strategic bets to actual values (4)
- Added "on_hold" status to schema
- Updated views to include on_hold
- Discussed Asana structure
- Confirmed native milestones with subtasks
- Confirmed native project status and owner
- Created users table for staff linking
- Added project_lead_id to projects
- Created upsert_project function (10 params)
- Started Make.com scenario for project sync
- Successfully connected to Asana API via Make.com
- Retrieved project data with all custom fields
- Set up hybrid Claude Code / chat documentation approach
- Created local project folder with claude.md, sql/schema.sql, sql/functions.sql
- Claude Code reviewed project and raised 5 clarifying questions

**Decisions made:**
1. Session log — docs/session-logs.md is canonical
2. Project code format — keep auto-generated ('P-' || asana_id) for now
3. strategic_bet_id — added to ON CONFLICT clause
4. project_type column — added to projects table
5. Added "Project Type" custom field in Asana (Standard Project vs Strategy Milestones)

**Added to scope:** Daily morale tracking from Slack (1-10 rating)

## 2026-02-02 (continued) — Make.com Project Sync

- Built Make.com scenario with Router pattern (5 branches: B1, B2, B3, B4, Upcoming Projects)
- Each branch: Asana API Call → Iterator → PostgreSQL Execute Function (upsert_project)
- Resolved Iterator configuration: array set to `{{4.body.data}}` (not concatenated with body)
- Resolved custom field extraction: index-based access (`{{5.custom_fields[2].display_value}}`) instead of get() function
- Fixed "no unique or exclusion constraint" error: added UNIQUE constraint on asana_project_id
- Fixed "null value in column asana_user_id": added NULL check for owner in function
- Fixed status constraint violations: added status mapping (off_track→blocked, null→not_started)
- Fixed focus cycle prefix: added REPLACE in function to strip "2026 " prefix
- Cleaned up duplicate function versions (old 9-param, new 10-param)

**Portfolio GIDs discovered:**
| Portfolio | Asana GID |
|-----------|-----------|
| B1: Video-Led Mentor Content | 1213026203855296 |
| B2: Informed Standardisation | 1213026203855292 |
| B3: Capacity through Automation | 1213026203855288 |
| B4: Owned Audience over SEO | 1213026203855284 |
| Upcoming Projects | 1213046199918957 |

**Test project synced successfully:** IO submission (B3, Development, Fraser Smith)

## 2026-02-02 (continued) — Milestone Sync

- Extended Make.com scenario: each bet branch now also syncs milestones
- Additional modules per branch: Asana API Call (project tasks) → Iterator → Filter (milestone only) → PostgreSQL Execute Function (upsert_milestone)
- Filter checks `resource_subtype = milestone` to only sync native Asana milestones
- Created upsert_milestone function (6 params: asana_id, project_asana_id, name, target_date, completed, focus_cycle)
- Fixed milestones status constraint: changed 'not_started' to 'upcoming'
- Fixed missing code column: added 'M-' || asana_id

**Asana API query for milestones:**
- opt_fields: `name,due_on,completed,resource_subtype,custom_fields.name,custom_fields.display_value`

## Metabase Persistence Fix

- Metabase was using H2 internal database — data lost on container restart
- Created `metabase_app` PostgreSQL database on same Sevalla instance
- Added environment variables: MB_DB_TYPE=postgres, MB_DB_HOST, MB_DB_PORT=5432, MB_DB_DBNAME=metabase_app, MB_DB_USER, MB_DB_PASS
- Redeployed container — Metabase now persistent across restarts
- HTTPS confirmed working on Sevalla domain

## Metabase Dashboards

- **Strategy 2026** dashboard: 8 questions (Strategic Overview, All Projects, Roadmap All Milestones, Roadmap By Month, Current Cycle Due, Alerts, Progress Summary, Upcoming Projects)
- **Focus Cycle View** dashboard: 4 questions with optional {{cycle}} filter variable
- Full query templates saved in docs/metabase-queries.md

## Slack Integration

- BsB Strategy Bot app created with OAuth scopes: chat:write, chat:write.public, channels:read, files:write
- Connected to Metabase for alerts/subscriptions
- Metabase→Slack image-based reports are unreliable (hangs, crashes Metabase)
- Recommendation: use Make.com for Slack notifications instead

## Upcoming Projects Pipeline

- Added "Upcoming Projects" as 5th branch in Make.com Router
- strategic_bet_id = NULL for pipeline items (not yet assigned to a bet)

## 2026-02-11

- Created GitHub remote: `git@github.com:fraserYT/bsb-strategy-system.git`
- Initial commit pushed to main branch
- Merged scratch file content from PhpStorm into local project

## 2026-02-12

- Designed daily check-in (mood & busyness) system
- Created `sql/checkin-schema.sql` — table, function, views
- Created `docs/daily-checkin-setup.md` — full step-by-step setup guide
- Architecture: Slack modal (via BsB Strategy Bot interactivity) → Make.com webhook → PostgreSQL
- Anonymity by design: user_id deliberately not stored
- Fun Question of the Day: separate system using Google Sheets + Slack Workflow Builder

## 2026-02-13

- Updated local files to match production database state
- Synced sql/functions.sql with final upsert_project (status mapping, prefix stripping, NULL owner check) and upsert_milestone
- Updated sql/schema.sql with code column on milestones, project_type on projects, corrected milestones status constraint
- Updated claude.md with all portfolio IDs, resolved pending decisions, current status

## 2026-02-16

- **Migrated strategic bets → initiatives + milestone tags**
- Renamed B1-B4 initiatives: Build Mentor Machine, Standardise Sales and Marketing Processes, Automate Key Processes, Optimise Subscriber Growth Engine
- Added B5: Rebrand to reflect who we are now
- Created `strategic_bet_tags` table (4 original bet names as cross-cutting tags)
- Created `milestone_bet_tags` junction table (milestone ↔ tag many-to-many)
- Updated `upsert_milestone` function: 7th param `p_strategic_bet_tags` (comma-separated, DEFAULT NULL for backwards compatibility)
- Updated `v_milestone_timeline` view: added `initiative_code`, `initiative_name`, `strategic_bet_tags` columns
- Created `v_milestone_tags` view: one row per milestone-tag pair for Metabase filtering
- Updated Metabase queries: "Bet" → "Initiative" aliases (Q1-Q4, Q6 Strategy; Q2-Q3 Focus Cycle)
- Added Strategic Bets column to Q3 Roadmap and Focus Cycle Q2
- Added Q9: Milestones by Strategic Bet Tag (cross-initiative view)
- Created `sql/migrate-initiatives.sql` — single transaction migration script for Sevalla
- Updated claude.md: initiative names, new tables, Asana structure (B5 portfolio, Strategic Bet custom field), Make.com docs (7th param)

**Key decision:** Keep `strategic_bets` table name as-is — renaming every FK, view, and function adds risk with no user-facing benefit. Metabase column aliases control what users see.

**Deployed to production:**
- Ran `sql/migrate-initiatives.sql` on Sevalla PostgreSQL (tables, data, indexes created; function needed `$fn$` quoting for Sevalla studio)
- Updated `upsert_milestone` function (7 params) — deployed separately due to `$$` parse issue
- Deployed `v_milestone_timeline` and `v_milestone_tags` views
- Updated all Metabase queries: "Bet" → "Initiative" across Q1-Q4, Q6, Q10-Q11
- Added Strategic Bets column to Q3 (All Milestones) and Q10 (Milestones by Focus Cycle)
- Added Q13 (Projects by Status), Q14 (Milestones by Strategic Bet Tag), Q15 (Milestone Timeline)
- Restructured `docs/metabase-queries.md` — single Strategy 2026 dashboard with 15 questions (removed fictional Focus Cycle View section)

**Note:** Sevalla SQL studio doesn't support `$$` dollar-quoting in PL/pgSQL functions. Use `$fn$` instead.

**Completed manually:**
- Asana: Renamed B1-B4 portfolios, created B5 portfolio, added "Strategic Bet" multi-select custom field to all projects
- Make.com: Added B5 initiative branch to sync scenario

**Remaining:**
- Make.com: Update all milestone sync modules with 7th param (`p_strategic_bet_tags`)
