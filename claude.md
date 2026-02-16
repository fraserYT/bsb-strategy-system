# BsB Strategy Planning System - Project Context

## Overview

Building an automated planning and execution system for annual strategy delivery.

**Goals:**
- Track projects aligned to 5 initiatives (formerly "strategic bets") across 6 focus cycles (8-week sprints)
- Automate sync between Asana (source of truth) and PostgreSQL (reporting hub)
- Dashboard visibility via Metabase
- Slack notifications for check-ins and progress
- Track daily team morale via Slack poll (1-10 rating), charted over time


**Tools:**
- Asana — project/task management
- PostgreSQL — central data hub (hosted on Sevalla)
- Metabase — dashboards (hosted on Sevalla)
- Make.com — automation/sync
- Slack — notifications (future)

---

## Architecture
┌─────────────────────────────────────────────────────────────┐  
│ ASANA (Source of Truth) │  
│ Portfolios → Projects → Milestones (tasks) → Subtasks │  
└─────────────────────┬───────────────────────────────────────┘  
│ Make.com (sync)  
▼  
┌─────────────────────────────────────────────────────────────┐  
│ POSTGRESQL (Central Hub) │  
│ Strategic Bets │ Projects │ Milestones │ Users │ etc. │  
└─────────────────────┬───────────────────────────────────────┘  
│  
┌───────────┴───────────┐  
▼ ▼  
┌──────────────────┐ ┌─────────────────────┐  
│ METABASE │ │ SLACK │  
│ (Dashboards) │ │ (Notifications) │  
└──────────────────┘ └─────────────────────┘


---

## Database Schema

### Tables

| Table | Purpose |
|-------|---------|
| `strategic_bets` | 5 initiatives (B1-B5), table name kept for FK compatibility |
| `focus_cycles` | 6 eight-week cycles (FC1-FC6) |
| `departments` | 10 teams |
| `users` | Staff members (synced from Asana) |
| `projects` | Projects within initiatives |
| `milestones` | Native Asana milestones within projects |
| `strategic_bet_tags` | 4 cross-cutting bet tags (multi-select on milestones) |
| `milestone_bet_tags` | Junction table linking milestones to bet tags |
| `strategy_milestones` | High-level outcomes per initiative |
| `proposals` | Intake pipeline items |
| `progress_snapshots` | Point-in-time progress records |

### Key Relationships

- Projects belong to one initiative and one department
- Projects have a project lead (user)
- Projects span focus cycles (start_cycle_id, end_cycle_id)
- Milestones belong to one project and one focus cycle
- Users linked by asana_user_id

### Initiatives (table: `strategic_bets`)

| Code | Name |
|------|------|
| B1 | Build Mentor Machine |
| B2 | Standardise Sales and Marketing Processes |
| B3 | Automate Key Processes |
| B4 | Optimise Subscriber Growth Engine |
| B5 | Rebrand to reflect who we are now |

### Strategic Bet Tags (table: `strategic_bet_tags`)

Cross-cutting tags applied to milestones via multi-select custom field in Asana. These are the original 4 bet concepts:

| Tag |
|-----|
| Video-Led Mentor Content |
| Informed Standardisation |
| Capacity through Automation |
| Owned Audience over SEO |

### Departments (Teams)

| Code | Name |
|------|------|
| PROD | Production |
| EDIT | Editorial |
| DEV | Development |
| INFRA | Infrastructure |
| WFS | Workflow Support |
| MKT | Marketing |
| SAL | Sales |
| BOARD | Board |
| STRAT | Strategy |
| DES | Design |

### Focus Cycles

| Code | Dates |
|------|-------|
| FC1 | 23 Feb – 5 Apr 2026 |
| FC2 | 13 Apr – 24 May 2026 |
| FC3 | 1 Jun – 12 Jul 2026 |
| FC4 | 20 Jul – 30 Aug 2026 |
| FC5 | 7 Sep – 18 Oct 2026 |
| FC6 | 26 Oct – 6 Dec 2026 |

### Project Status Values

`not_started`, `on_track`, `at_risk`, `blocked`, `on_hold`, `complete`, `cancelled`

---

## Asana Structure

### Portfolio Hierarchy
📁 🎯 BsB Strategy 2026 (top-level portfolio)
├── 📁 🧩 Build Mentor Machine (B1)
├── 📁 🧩 Standardise Sales and Marketing Processes (B2)
├── 📁 🧩 Automate Key Processes (B3)
├── 📁 🧩 Optimise Subscriber Growth Engine (B4)
├── 📁 🧩 Rebrand to reflect who we are now (B5)
└── 📋 📥 Upcoming Projects (Intake Pipeline)


### Project Custom Fields (Portfolio Level)

| Field | Type | Options |
|-------|------|---------|
| Project Type | Dropdown | Standard Project, Strategy Milestones |
| Teams | Dropdown | (existing field - 10 teams) |
| Start Cycle | Dropdown | 2026 FC1 - 2026 FC6 |
| End Cycle | Dropdown | 2026 FC1 - 2026 FC6 |

**Note:** Status uses native Asana project status (On Track, At Risk, Off Track, On Hold, Complete)

**Note:** Project Owner uses native Asana field

### Project Structure
📋 Project Name  
├── ◆ Milestone 1 (native milestone task)  
│ ├── Custom field: Focus Cycle  
│ ├── Subtask: Work item A  
│ └── Subtask: Work item B  
├── ◆ Milestone 2 (native milestone task)  
│ └── Subtasks...  
└── ◆ Milestone 3 (native milestone task)  
└── Subtasks...


### Milestone Custom Fields (Task Level)

| Field | Type | Options |
|-------|------|---------|
| Focus Cycle | Dropdown | FC1-FC6 |
| Strategic Bet | Multi-select | Video-Led Mentor Content, Informed Standardisation, Capacity through Automation, Owned Audience over SEO |

### Portfolio IDs

| Portfolio | Asana GID |
|-----------|-----------|
| 🧩 Build Mentor Machine (B1) | 1213026203855296 |
| 🧩 Standardise Sales and Marketing Processes (B2) | 1213026203855292 |
| 🧩 Automate Key Processes (B3) | 1213026203855288 |
| 🧩 Optimise Subscriber Growth Engine (B4) | 1213026203855284 |
| 🧩 Rebrand to reflect who we are now (B5) | 1213297368366399 |
| 📥 Upcoming Projects | 1213046199918957 |

---

## Metabase Configuration

### Hosting

Metabase runs as a Docker container on Sevalla, storing its internal data in PostgreSQL (not H2) for persistence.

| Variable | Value |
|----------|-------|
| `MB_DB_TYPE` | `postgres` |
| `MB_DB_HOST` | *(PostgreSQL host)* |
| `MB_DB_PORT` | `5432` |
| `MB_DB_DBNAME` | `metabase_app` |
| `MB_DB_USER` | *(PostgreSQL username)* |
| `MB_DB_PASS` | *(PostgreSQL password)* |

Business database connection added via Metabase UI: `bitesize_bio`

### Dashboards

| Dashboard | Questions | Details |
|-----------|-----------|---------|
| Strategy 2026 | 8 queries | Strategic overview, all projects, roadmap, alerts, progress |
| Focus Cycle View | 4 queries | Cycle overview, milestones by cycle, active projects, cycle progress |

Full query templates: [`docs/metabase-queries.md`](docs/metabase-queries.md)

---

## Make.com Scenarios

### Scenario: Asana → PostgreSQL: Sync Projects

**Status:** In progress

**Structure:** Router with branches for each portfolio (B1, B2, B3, B4, B5, Upcoming Projects). Each branch:
1. Asana — Make an API Call → `GET /1.0/portfolios/{portfolio_gid}/items`
2. Iterator → iterate through projects
3. PostgreSQL — Execute Function → `upsert_project()`

**Portfolio GIDs:**

| Portfolio | Asana GID |
|-----------|-----------|
| B1: Build Mentor Machine | `1213026203855296` |
| B2: Standardise Sales and Marketing Processes | `1213026203855292` |
| B3: Automate Key Processes | `1213026203855288` |
| B4: Optimise Subscriber Growth Engine | `1213026203855284` |
| B5: Rebrand to reflect who we are now | `1213297368366399` |
| Upcoming Projects | `1213046199918957` |

**Key mappings:**
- `strategic_bet_id = NULL` for Upcoming Projects branch
- `strategic_bet_id = corresponding bet ID` for B1-B4 branches
- Custom fields extracted via index-based access: `{{5.custom_fields[2].display_value}}`

**Function: upsert_project** (10 parameters)

| Parameter | Source |
|-----------|--------|
| p_asana_id | `{{5.gid}}` |
| p_name | `{{5.name}}` |
| p_bet_code | Hard-coded per branch (B1/B2/B3/B4/NULL) |
| p_team_name | `{{5.custom_fields[N].display_value}}` (Teams field) |
| p_owner_asana_id | `{{5.owner.gid}}` |
| p_owner_name | `{{5.owner.name}}` |
| p_status | `{{5.current_status_update.status_type}}` |
| p_start_cycle | `{{5.custom_fields[N].display_value}}` (Start Cycle field) |
| p_end_cycle | `{{5.custom_fields[N].display_value}}` (End Cycle field) |
| p_project_type | `{{5.custom_fields[N].display_value}}` (Project Type field) |

**Function: upsert_milestone** (7 parameters)

| Parameter | Source |
|-----------|--------|
| p_asana_id | milestone task gid |
| p_project_asana_id | parent project gid |
| p_name | milestone task name |
| p_target_date | milestone due_on |
| p_completed | milestone completed boolean |
| p_focus_cycle | Focus Cycle custom field display_value |
| p_strategic_bet_tags | Strategic Bet custom field display_value (comma-separated, optional) |

**Asana API query strings:**
- Projects: `opt_fields: name,owner.name,owner.gid,current_status_update.status_type,custom_fields.name,custom_fields.display_value`
- Milestones: `opt_fields: name,due_on,completed,resource_subtype,custom_fields.name,custom_fields.display_value`

**Milestone sync flow** (per initiative branch):
Asana API Call (project tasks) → Iterator → Filter (`resource_subtype = milestone`) → PostgreSQL Execute Function (upsert_milestone)

**Note:** After deploying the updated `upsert_milestone` function, refresh the function list in each PostgreSQL module in Make.com, then add the 7th parameter mapping for `p_strategic_bet_tags` → `{{N.custom_fields[X].display_value}}` (Strategic Bet multi-select field).

---

## Slack Integration

### App: BsB Strategy Bot

**OAuth Scopes:**
- `chat:write`
- `chat:write.public`
- `channels:read`
- `files:write`

**Token:** Bot User OAuth Token (starts with `xoxb-`) — stored in Make.com / Sevalla, not in repo.

**Status:** Connected to Metabase but unreliable for image-based reports. Recommend using Make.com for Slack notifications instead.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Single owning team per project | Simpler; process ensures one team assigned |
| Native Asana milestones | Have due dates, appear on timeline, can complete |
| Subtasks under milestones | Clear semantic grouping, progress tracking |
| Project Type custom field | Can't rely on naming conventions |
| Native project status | Avoid redundant custom field |
| Native project owner | Avoid redundant custom field |
| Users table with Asana ID | Future-proof linking, names can change |
| Focus cycle values prefixed "2026 FC1" in Asana | Strip prefix during sync |
| Keep `strategic_bets` table name | Avoid renaming every FK, view, function; Metabase aliases control display |
| Initiatives vs bet tags | Initiatives = portfolios (B1-B5); bet tags = cross-cutting multi-select on milestones |

---

## Session Log

### 2026-01-30
- Set up PostgreSQL database on Sevalla
- Created schema (8 tables)
- Added dummy data
- Created indexes and views
- Set up Metabase on Sevalla
- Built executive dashboard (8 cards)

### 2026-02-02
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
- Claude Code reviewed project and raised 5 clarifying questions

**Decisions resolved:**
1. Session log — docs/session-logs.md is canonical
2. Portfolio IDs — all discovered (see Portfolio IDs section)
3. Project code format — keep auto-generated ('P-' || asana_id)
4. strategic_bet_id — added to ON CONFLICT clause in upsert_project
5. project_type column — added to projects table and upsert_project function

**Added to scope:** Daily morale tracking from Slack (1-10 rating), Fun Question of the Day

---

## Current Status

### Working
- Database schema complete (all columns, constraints, functions match production)
- Metabase persistent via metabase_app PostgreSQL database (not H2)
- One Metabase dashboard: Strategy 2026 (15 questions)
- Make.com project sync: all 6 branches (B1-B5 + Upcoming) working with upsert_project
- Make.com milestone sync: all initiative branches syncing native milestones via upsert_milestone (7 params, tag sync ready)
- Database migrated: initiatives renamed (B1-B5), strategic_bet_tags + milestone_bet_tags tables live
- Views updated: v_milestone_timeline (with initiative + tag columns), v_milestone_tags
- Slack Bot (BsB Strategy Bot) connected to Metabase alerts
- HTTPS confirmed on Sevalla domain

### Designed but Not Yet Implemented
- Daily check-in system (mood & busyness) — schema and Make.com guide ready
- Fun Question of the Day — Google Sheets + Slack Workflow approach documented

### Next Steps
1. Make.com: Update all milestone sync modules with 7th param (`p_strategic_bet_tags`)
2. Run `sql/checkin-schema.sql` on Sevalla PostgreSQL
5. Build Make.com check-in scenarios (daily post + webhook handler)
6. Configure Slack interactivity for check-in modal
7. Build Metabase check-in dashboard cards
8. Set up Google Sheet + Slack Workflows for fun questions
9. Build Make.com scenarios for Slack status notifications (replacing unreliable Metabase→Slack)
10. Add dashboard filters (initiative, status, department) to Strategy 2026 dashboard
11. Populate Asana with all FC1 projects
12. Build proposal sync scenario
13. Set up scheduled Make.com runs
14. Produce strategy system manual/documentation

---

## Known Issues

- Focus cycle values in Asana include "2026 " prefix — stripped during sync
- Make.com custom field extraction requires get() function
- Must refresh Make.com function list after database changes
- Sevalla SQL studio doesn't support `$$` dollar-quoting — use `$fn$` for PL/pgSQL functions

---

## Morale Tracking

Two separate daily Slack interactions:

1. **Mood & Busyness Check-in** — anonymous 1-10 ratings via Slack modal, stored in PostgreSQL, charted in Metabase. Built with Make.com + Slack interactivity (BsB Strategy Bot).
2. **Fun Question of the Day** — Google Sheet + Slack Workflow Builder ([Aaron Heth approach](https://aaronheth.medium.com/slack-hack-make-a-completely-automated-question-of-the-day-system-for-your-team-with-no-plugins-4dbdd26a0573)). No database involvement.

**Anonymity:** Slack modal submissions include user_id but Make.com deliberately does not store it. Only response_date, mood_rating, busyness_rating go into PostgreSQL. Metabase cards should filter to 3+ responses/day on small teams.

**Status:** Schema and Make.com guide complete, implementation not started.

**Files:**
- `sql/checkin-schema.sql` — table, function, views (ready to run)
- `docs/daily-checkin-setup.md` — full step-by-step setup guide

**Implementation order:**
1. Run schema SQL on Sevalla PostgreSQL
2. Create Make.com Scenario 2 (webhook + router) — need URL before Slack config
3. Enable Interactivity on BsB Strategy Bot, set Request URL to webhook
4. Complete Scenario 2 branches (button→modal, submission→insert_checkin)
5. Create Make.com Scenario 1 (scheduled daily post with Block Kit button)
6. Test full flow end-to-end
7. Build Metabase dashboard cards
8. Set up Google Sheet + Slack Workflows for fun questions
9. Announce to team, disable DailyBot

---

## Test Project

| Field | Value |
|-------|-------|
| Name | IO submission |
| Asana GID | 1213046199918993 |
| Portfolio | 🧩 Capacity through Automation (B3) |
| Owner | Fraser Smith (GID: 91129375466877) |
| Status | on_track |
| Teams | Development |
| Start Cycle | 2026 FC1 |
| End Cycle | 2026 FC2 |
| Project Type | Strategy Milestones |
