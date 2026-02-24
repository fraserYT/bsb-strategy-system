u# Session Log

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

## 2026-02-23 (continued) — Client DB Migration

- Planned full IO automation scope across FC1/FC2
- Dropped and reimported `bsb_client_codes` from Google Sheet CSV (85 records, up from 78)
- Created and populated `clients` table (49 unique companies, keyed by TLA)
- Added `tla VARCHAR(20)` column to `clients`
- Changed `po_required` from BOOLEAN to TEXT (preserves values like "Yes (Coupa)")
- Cleaned data: stripped `mailto:` prefix from emails, moved code annotations (LMS002, ZEI003) to notes, normalised embedded newlines in addresses
- Migration scripts saved to `sql/client_migration/` (5 files, run in order)

## 2026-02-23

- Introduced IO Submission automation (Make.com Phase 1) to project context
- Stored blueprint in `make-blueprints/phase-1-io-submission-project-creation.json`
- Reviewed blueprint and identified issues: race condition on DB insert, rerun failures on conflict
- Discovered new tables in production not reflected in local schema: `clients`, `bsb_client_codes`, `insertion_orders`, `checkin_responses`
- Updated `sql/schema.sql` with all four tables
- Added `upsert_insertion_order` function to `sql/functions.sql`
  - Handles Yes/No → boolean for `new_client`
  - Handles ISO date strings (YYYY-MM-DD) from Gravity Forms via Google Sheets
  - ON CONFLICT (io_reference) DO NOTHING; returns existing id if record already exists
- Added `update_insertion_order_links` function to `sql/functions.sql`
  - Updates asana_link, drive_link, goal_link by io_reference
  - Constructs full Asana goal URL from raw GID; preserves existing values if param is empty

**IO Submission scenario — Make.com changes needed:**
1. Replace `InsertIntoTable` (module 34, Branch B) with `Execute Function → upsert_insertion_order`
   - Move the call into Branch A's main flow, positioned after module 10 (sheet write-back)
   - This eliminates the race condition (links currently read from sheet before they're written)
2. Add `Execute Function → update_insertion_order_links` at end of Branch A
   - Pass `{{9.Asana Link}}` for asana_link
   - Pass `https://drive.google.com/drive/u/0/folders/{{12.id}}` for drive_link
   - Pass `{{14.data.data.gid}}` for goal_gid
3. Fix `additionalContactsJ` variable (carriage return stripping for JSON) — still outstanding

**PENDING VERIFICATION — check on next real IO submission:**

Run this query in Sevalla after the scenario completes:
```sql
SELECT
    io_reference,
    salesperson_email,
    submission_date,
    date_io_signed,
    new_client,
    company_name,
    asana_link,
    drive_link,
    goal_link,
    created_at
FROM insertion_orders
ORDER BY created_at DESC
LIMIT 5;
```

Confirm:
- [ ] Record was created (not a conflict-skipped no-op)
- [ ] `submission_date` and `date_io_signed` are populated, not NULL
- [ ] `new_client` is `true`/`false`, not NULL
- [ ] `asana_link`, `drive_link`, `goal_link` are all populated (confirms race condition fix)
- [ ] Running the scenario a second time on the same row completes without error and creates no duplicate

**IO Submission context:**
- Source: Gravity Forms on internal website → Google Sheets → Make.com
- Future: HubSpot as source (long-term, not imminent)
- Dates stored as text with leading apostrophe in sheet (e.g. `'2025-12-02`); Make.com receives without apostrophe as ISO format
- `new_client` field comes through as text "Yes"/"No" from the form

## 2026-02-24

- Reviewed current Make.com blueprint (`temp/current_scenario.json`) — confirmed v6d.1 and v6d.2 already implemented:
  - Race condition fixed: `upsert_insertion_order` (module 52) now runs inline in Branch A after sheet write-back (module 10), Branch B removed
  - `update_insertion_order_links` (module 54) follows immediately with correct link params
  - Old `InsertIntoTable` module 34 removed
- Closed beads tasks v6d.1 and v6d.2
- Reorganised beads: closed kre, downgraded ffo/pj7/a8y/6p3 to P3/on-hold, bumped v6d and new FC1 tasks to P1
- Added new beads epics: IO Automation FC1 Workplan (l8h), Client Reporting Automation (43l)
- Added colleague onboarding task (d1b), 84e deferred to tomorrow, 43l blocked until d1b complete

**Drive folder structure — DB schema deployed to Sevalla:**
- Added `drive_folder_id TEXT` to `clients` (Tier 1 folder ID cache)
- Added `drive_folder_id TEXT` to `bsb_client_codes` (Tier 2 folder ID cache)
- Created `client_product_folders` table (Tiers 3+4: product type + year folder IDs)
- Deployed 4 new functions (all tested and verified):
  - `get_client_folder_info(client_code)` — returns TLA, names, Tier 1+2 folder IDs
  - `update_client_folder_ids(client_code, tier1_id, tier2_id)` — stores folder IDs after creation
  - `get_product_folder_info(client_code, product_type, year)` — returns Tier 3+4 folder IDs
  - `upsert_product_folder(client_code, product_type, year, tier3_id, tier4_id)` — stores Tier 3+4 IDs
- Note: Sevalla SQL studio runs entire editor content as one batch — functions must be pasted alone using single-quoted bodies (not dollar-quoting)
- Root "Client Projects" Drive folder ID: `1PURGWZSK1gMTJN7GDYogY1Q0_ohsUkht`

**Remaining for l8h.1 (Drive folder structure):**
1. Folder audit — scan Client Projects, match to DB by TLA/code, populate folder IDs, output non-conforming folders to Google Sheet
2. Make.com flow update — replace current flat folder creation with 4-tier find-or-create logic using the new DB functions

**New project captured:**
- Client Reporting Automation (claude-wp-43l) — replace manual multi-platform report collation with automated pipeline → Metabase → PDF. Colleague is primary driver. Blocked on onboarding (d1b).

## 2026-02-24 (continued) — Drive Folder Audit Script

- Created `scripts/audit_drive_folders.py` — Python script to audit Drive folder structure against DB
- Uses OAuth2 user credentials (manager access to Client Projects folder is sufficient)
- Scans Tier 1 folders under Client Projects (ID: `1PURGWZSK1gMTJN7GDYogY1Q0_ohsUkht`) in Shared Drive (ID: `0AB1AZiOLJI_ZUk9PVA`)
- Matches `[TLA] Client Name` pattern → updates `clients.drive_folder_id`
- Optional `--tier2` flag: also scans `[CODE] Contact Name` subfolders → updates `bsb_client_codes.drive_folder_id`
- Dry-run by default; `--apply` to write to DB; outputs `audit_results.csv` with status per folder

**Setup required before running:**
1. Get `client_secrets.json` from GCP console (Drive API enabled, Desktop app OAuth2 credentials) → save to `scripts/client_secrets.json`
2. Set env vars in `scripts/scripts.env`: `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`, `DB_PORT=30067`
3. First run opens browser for Google auth — token cached in `scripts/token.json` (gitignored)

**Sevalla external connection notes:**
- Host: `europe-north1-001.proxy.sevalla.app`
- Port: `30067` (not 5432)
- SSL: not required (server doesn't support it)
- DB name: not `bitesize_bio` — check Sevalla dashboard for actual external DB name

**Audit run results (2026-02-24):**
- 47 Tier 1 folders found in Client Projects
- 41 folder IDs written to `clients.drive_folder_id` ✅
- 4 outstanding — need action before re-running with `--apply`:

| Folder in Drive | Issue | Action |
|-----------------|-------|--------|
| `[BoB]` Boster Bio | Mixed case TLA | Rename to `[BOB]` in Drive |
| `[DeN]` DeNovix | Mixed case TLA | Rename to `[DEN]` in Drive |
| `[N6]` N6 Tec | TLA mismatch | Rename to `[N6T]` in Drive (DB uses N6T) |
| `[OSS]` Ossila Ltd | TLA mismatch | Waiting on confirmation — DB has `OOS`, Drive has `OSS`. Colleague checking which is correct |
| `[ELR]` ELRIG | Not in DB | Waiting on colleague to add details to sheet and DB |

**Outstanding items resolved (2026-02-24 continued):**

| Folder in Drive | Resolution | Action |
|-----------------|------------|--------|
| `[BoB]` Boster Bio | Mixed case | **Rename to `[BOB]` in Drive** (user action) |
| `[DeN]` DeNovix | Mixed case | **Rename to `[DEN]` in Drive** (user action) |
| `[N6]` N6 Tec | TLA mismatch | **Rename to `[N6T]` in Drive** (user action) |
| `[OSS]` Ossila Ltd | DB had `OOS` (typo) | Run `sql/fix-ossila-tla.sql` on Sevalla — updates clients, bsb_client_codes, insertion_orders |
| `[ELR]` ELRIG | Not in DB | Added to sheet — run `scripts/sync_client_sheet.py --apply` to sync to DB |

**Completed (2026-02-24):**
1. `sql/fix-ossila-tla.sql` run on Sevalla ✅
2. `sync_client_sheet.py --apply` — 50 clients, 84 codes synced (incl. ELRIG, OSS, BOB, DEN, N6T) ✅
3. Drive renames done (BOB, DEN, N6T) ✅
4. Tier 1 audit complete — 46 folder IDs in DB ✅
5. Tier 2 audit complete — 78 folder IDs in DB ✅

**Outstanding (for colleague):** See `docs/drive-audit-tier2-report.md`
- `[N6T] Jenny Alfrey` → rename to `[N6T001] Jenny Alfrey` in Drive, then re-run `--tier2 --apply`
- ZEI Podcast folder — decision needed
- 8 misc/archive folders — confirm OK to leave as-is

**New script: `scripts/sync_client_sheet.py`**
- Reads client directory sheet, calls `upsert_client` + `upsert_client_code` for every row
- Safe to re-run (all upserts) — use as the ongoing sheet→DB sync mechanism
- Requires Sheets scope: delete `token.json` before first run (re-auth adds both Drive + Sheets scopes)
- Dry-run by default; `--apply` to write

**New task: `claude-wp-l8h.5`** — decide on ongoing sheet/DB sync schedule (manual vs. Make.com vs. cron)

## 2026-02-24 (continued) — l8h.2 and l8h.4

### l8h.2: New client handling on IO form

**DB changes (`sql/migrate-new-client.sql`) — deployed ✅:**
1. `ALTER TABLE clients ADD CONSTRAINT clients_tla_unique UNIQUE (tla)`
2. `upsert_client(p_tla, p_client_name, p_formatted_client_name)` — returns clients.id
3. `upsert_client_code(p_bsb_client_code, p_tla, p_primary_contact, p_primary_contact_email, p_payment_terms, p_po_required, p_billing_contact, p_billing_email, p_billing_address)` — returns bsb_client_codes.id

**Gravity Form — contact field pre-population (GPPA, no WordPress code needed):**
The client directory sheet (`1hSSJCG-QR6R6XIyB-CrxryDhA3_XqBt-SqhG9Oqy96E`) has `Primary contact`, `Primary Contact Email`, and all billing columns — exactly matching what GPPA already uses for Company Name fields.

Changes to the form:
1. Change field 10 (Primary Client Contact) from **Name type → Text type** (the sheet has a single full-name column, not first/last)
2. Add GPPA to field 10: pull `Primary contact`, filter `BsB Client Code` = field 6
3. Add GPPA to field 11: pull `Primary Contact Email`, filter `BsB Client Code` = field 6
4. Both fields remain editable and required — salesperson can override if contact has changed
5. For new clients (field 7 checked): GPPA returns nothing (no sheet row yet), fields are blank — salesperson fills in

Note: The bio theme uses domain-based site selection logic (`bio_domain_specific()` in `functions.php`). The staff site (`bsbstaff.com`) has no brand include file yet — any future WordPress code for this site goes in the `bsbstaff` case or a new `inc/brands/bsbstaff.php`. Not needed for this task.

**Gravity Form — new client fields to add (conditional on New Client = Yes):**
| Field | Type | Maps to |
|-------|------|---------|
| Company TLA | Text (uppercase) | `p_tla` |
| Full company name | Text | `p_client_name` |
| Formatted company name | Text (optional) | `p_formatted_client_name` |
| Client code | Text (e.g. ABC001) | `p_bsb_client_code` |
| Payment terms | Dropdown | `p_payment_terms` |
| PO required | Dropdown | `p_po_required` |
| Billing contact name | Text (optional) | `p_billing_contact` |
| Billing contact email | Email (optional) | `p_billing_email` |
| Billing address | Textarea (optional) | `p_billing_address` |

Note: Primary contact name (field 10) and email (field 11) are already on the form — no duplicate fields needed. Make.com uses them for both the IO record and `upsert_client_code`.

**Make.com changes (to IO submission scenario):**
1. Update field 10 reference from `{Primary Client Contact (First):10.3}` + `{Primary Client Contact (Last):10.6}` → `{Primary Client Contact:10}` (now a single text field)
2. Add a branch that fires when `new_client = "Yes"`, running BEFORE Drive folder creation:
   - PostgreSQL Execute Function → `upsert_client`
   - PostgreSQL Execute Function → `upsert_client_code` (uses field 10 for `p_primary_contact`, field 11 for `p_primary_contact_email`)
   - Google Sheets → Add a Row to client directory sheet (keeps dropdown and GPPA current for future submissions)

### l8h.4: Milestone sync 7th param

**Make.com changes only — no DB work needed.**

In the Asana→PostgreSQL sync scenario, for each of the 5 initiative branches (B1–B5):
1. Find the milestone API call module — check the custom_fields array in the output to identify the index of the "Strategic Bet" field (open a test run, look at the custom_fields array — it's likely index 0 or 1)
2. Open the PostgreSQL Execute Function module (upsert_milestone)
3. Click Refresh on the function list
4. Add 7th parameter: `p_strategic_bet_tags` → `{{N.custom_fields[X].display_value}}` where N is the Iterator module number and X is the Strategic Bet field index

**Note:** The Strategic Bet field is a multi-select in Asana. `display_value` returns a comma-separated string, which is exactly what `upsert_milestone` expects for the 7th param.

## 2026-02-24 (continued) — Make.com Cosmetic Fixes (this week)

Two small formatting issues identified in the Asana creation process. Tracked as beads tasks, to be resolved this week.

**`claude-wp-ohj` — Fix primary contact email missing from Asana creation (Make.com) [P1]**
Primary contact email is not appearing in Asana on IO submission. Investigate field mapping in Make.com scenario — likely dropped between Gravity Form / Google Sheet and the Asana creation module. Confirmed missing on most recent submission.

**`claude-wp-2p2` — Fix goal name missing spaces (Make.com)**
Goal names in the Asana creation step are concatenated without spaces between components.
- Current: `3772167385472026-02-18Sarah FarrowCYT001`
- Fix: add spaces/separators between IO reference, date, contact name, and client code
- Fix is in the Make.com scenario (string construction for goal name)

**`claude-wp-5zo` — Replace pipes with spaces in additional contacts field (Make.com)**
Additional contacts currently arrive as `firstname|lastname|email@address.com` — pipes need replacing with spaces before the value is passed to Asana.
