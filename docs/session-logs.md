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
- Created users table for staff
- Added project_lead_id to projects
- Created upsert_project function (10 params)
- Started Make.com scenario for project sync
- Successfully connected to Asana API via Make.com
- Retrieved project data with all custom fields
- Set up hybrid Claude Code / chat documentation approach
- Created local project folder with CLAUDE.md, sql/schema.sql, sql/functions.sql
- 
- 
- Claude Code reviewed project and raised 5 clarifying questions

**Decisions pending (from Claude Code review):**
1. Session log duplication — make docs/ canonical
2. Missing portfolio IDs for B1, B2, B4 — to be discovered
3. Project code format — keep auto-generated for now
4. strategic_bet_id — add to ON CONFLICT clause
5. project_type column — add to projects table

**Added to scope:** Daily morale tracking from Slack (1-10 rating)

**Paused at:** Make.com scenario — mapping Iterator output to upsert_project parameters

### Next session
1. Apply database fixes (strategic_bet_id update, project_type column)
2. Complete Make.com field mapping
3. Test sync with IO submission project
4. Design morale tracking schema
