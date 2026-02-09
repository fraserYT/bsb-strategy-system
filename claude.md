# BsB Strategy Planning System - Project Context

## Overview

Building an automated planning and execution system for annual strategy delivery.

**Goals:**
- Track projects aligned to 4 strategic bets across 6 focus cycles (8-week sprints)
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
| `strategic_bets` | 4 annual bets (B1-B4) |
| `focus_cycles` | 6 eight-week cycles (FC1-FC6) |
| `departments` | 10 teams |
| `users` | Staff members (synced from Asana) |
| `projects` | Projects within bets |
| `milestones` | Native Asana milestones within projects |
| `strategy_milestones` | High-level outcomes per bet |
| `proposals` | Intake pipeline items |
| `progress_snapshots` | Point-in-time progress records |

### Key Relationships

- Projects belong to one strategic bet and one department
- Projects have a project lead (user)
- Projects span focus cycles (start_cycle_id, end_cycle_id)
- Milestones belong to one project and one focus cycle
- Users linked by asana_user_id

### Strategic Bets

| Code | Name |
|------|------|
| B1 | Video-Led Mentor Content |
| B2 | Informed Standardisation |
| B3 | Capacity through Automation |
| B4 | Owned Audience over SEO |

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
├── 📁 🧩 Video-Led Mentor Content (B1)  
├── 📁 🧩 Informed Standardisation (B2)  
├── 📁 🧩 Capacity through Automation (B3)  
├── 📁 🧩 Owned Audience over SEO (B4)  
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

### Portfolio IDs

| Portfolio | Asana ID |
|-----------|----------|
| 🧩 Capacity through Automation (B3) | 1213026203855288 |
| *(add others as discovered)* | |

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

**Structure:** Router with branches for each portfolio (B1, B2, B3, B4, Upcoming Projects). Each branch:
1. Asana — Make an API Call → `GET /1.0/portfolios/{portfolio_gid}/items`
2. Iterator → iterate through projects
3. PostgreSQL — Execute Function → `upsert_project()`

**Portfolio GIDs:**

| Portfolio | Asana GID |
|-----------|-----------|
| Upcoming Projects | `1213046199918957` |
| B3: Capacity through Automation | `1213026203855288` |
| B1, B2, B4 | *(obtain from Asana URLs)* |

**Key mappings:**
- `strategic_bet_id = NULL` for Upcoming Projects branch
- `strategic_bet_id = corresponding bet ID` for B1-B4 branches

**Function: upsert_project**

Parameters (10):
- p_asana_id
- p_name
- p_bet_code
- p_team_name
- p_owner_asana_id
- p_owner_name
- p_status
- p_start_cycle
- p_end_cycle
- p_project_type

**Query string for Asana API:**
- opt_fields: `name,owner.name,owner.gid,current_status_update.status_type,custom_fields.name,custom_fields.display_value`

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

**Decisions pending (from Claude Code review):**
1. Session log duplication — make docs/ canonical
2. Missing portfolio IDs for B1, B2, B4 — to be discovered
3. Project code format — keep auto-generated for now
4. strategic_bet_id — add to ON CONFLICT clause
5. project_type column — add to projects table

**Added to scope:** Daily morale tracking from Slack (1-10 rating)

---

## Current Status

### Working
- Database schema complete
- Metabase connected and dashboard built (needs real data)
- Asana API call returning project data with all fields

### In Progress
- Make.com scenario: mapping Iterator output to upsert_project parameters

### Next Steps
1. Apply database fixes (strategic_bet_id update, project_type column)
2. Complete Make.com field mapping
3. Test sync with IO submission project
4. Add remaining portfolio API calls (B1, B2, B4)
5. Build milestone sync scenario
6. Build strategy milestone sync scenario
7. Build proposal sync scenario
8. Design morale tracking schema
9. Set up scheduled runs
10. Slack notifications

---

## Known Issues

- Focus cycle values in Asana include "2026 " prefix — stripped during sync
- Make.com custom field extraction requires get() function
- Must refresh Make.com function list after database changes

---

## Morale Tracking

**Source:** Daily Slack poll asking team to rate mood 1-10

**Requirements:**
- Store daily responses (user, date, rating)
- Chart aggregate mood over time (daily/weekly average)
- Visible on dashboard alongside project health

**Status:** Not started — schema design pending

**Questions to resolve:**
- Which Slack channel?
- Anonymous or attributed responses?
- How is the poll triggered? (Slack workflow, bot, manual)
- Store individual responses or just daily aggregates?

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
