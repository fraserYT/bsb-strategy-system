# IO Submission Automation

## What This System Does

When a salesperson closes a new Insertion Order (IO), they fill in a form on an internal website. From that single submission, the system automatically creates everything the team needs to start delivering: a project record in Asana, a goal linked to the relevant initiative, a client folder in Google Drive, a Slack notification to the team, and a record in the database.

The goal is to eliminate the manual project setup work that previously happened after every sale, reduce the risk of things being missed, and give everyone immediate visibility that a new IO has landed.

---

## The Submission Flow (From a Salesperson's Perspective)

1. Close the deal and get the IO signed.
2. Go to the internal website and complete the IO submission form (powered by Gravity Forms).
3. Upload the signed IO PDF and fill in the client and product details.
4. Submit the form.

That's it. The form response is recorded in a Google Sheet, which triggers the automation. Within a minute or two, everything below will have been created automatically.

---

## What Gets Created Automatically

For every IO submission, the system creates:

- **An Asana Goal** — tied to the relevant initiative, with the client name and IO reference
- **An Asana task** in the IO submission log project, so the ops team can track incoming work
- **A Google Drive folder** for the IO, under the client's folder hierarchy
- **A subfolder** for each deliverable listed on the IO
- **A Slack notification** to `all-bitesizebio` so the team is informed immediately
- **A database record** in the `insertion_orders` table for reporting and dashboards

For **Live Events (BsB)**, the system additionally:

- Duplicates an Asana project from the standard live event template
- Generates a pre-filled registration form URL

Once the folders and Asana records are created, the system writes the Asana link, Drive link, and Goal ID back into the Google Sheet, so the original submission row acts as a permanent reference.

---

## What the Form Captures

The form collects the following information, which lands as a row in the Google Sheet:

| Field | Description |
|---|---|
| Salesperson | Name of the salesperson |
| Salesperson email | For follow-up and Asana task assignment |
| Submission date | When the form was submitted |
| Date IO signed | When the client signed the IO |
| IO reference | Unique reference number for the IO |
| BSB client code | The internal code identifying the client contact |
| New client | Yes/No — whether this is a first-time client |
| Company name | Full company name |
| Primary client contact | Contact person at the client |
| Primary client email | Contact email |
| Additional contacts | Any other contacts to include |
| Notes/comments | Salesperson notes for the delivery team |
| Product type | The category of deliverable (e.g. Live Event, eBlast) |
| Signed IO PDF | Uploaded copy of the signed document |

A separate "Products" sheet lists the individual deliverables for each IO, matched by IO reference. Each deliverable gets its own subfolder and, where supported, its own Asana project.

---

## Current Status

### Live and Working

- Form submission triggers the Make.com automation
- Asana Goal creation
- Asana IO submission log task
- Google Drive folder creation (top-level IO folder)
- Per-deliverable subfolder creation
- Slack notification to `all-bitesizebio`
- Write-back of Asana link, Drive link, and Goal ID to the Google Sheet
- Database record creation in `insertion_orders`
- Live Event (BsB) routing: Asana project duplication from template, pre-filled registration form URL generation

### Pending / Known Issues

The following are known issues being worked on:

1. **Drive folder link in the database** — The `io_products` table now captures the Drive folder ID for each product. The Asana project link remains nullable until per-product Asana project creation is built out.

2. **Additional contacts formatting** — A bug with carriage return characters in the additional contacts field is causing issues with JSON encoding. This is outstanding.

3. **Milestone sync parameter** — A pending update across all milestone sync modules to add a new tagging parameter. The database function is already deployed; the Make.com configuration just needs updating.

---

### 4-Tier Drive Folder Implementation — Manual Make.com Steps

The 4-tier Drive folder logic (replacing flat modules 12 and 23) needs to be built manually in Make.com due to cross-branch reference scoping constraints. The programmatic blueprint approach breaks because Make.com does not allow modules in one router branch to reference outputs from a different router's branch.

**The fix:** Add a SetVariables module in the **main flow** after each conditional router to resolve the folder ID before the next stage needs it. Because these SetVars are in the main flow (not inside a branch), they CAN reference module outputs from upstream router branches.

**Full sequence to build inside the iterator (after module 32), replacing modules 12 and 23:**

#### 57 — SetVariables
- `tier3FolderName` → product type mapping:
  `{{if(40.\`0\` = "Live Event"; "Live Events"; if(40.\`0\` = "eBlast"; "eBlasts"; if(40.\`0\` = "Podcast"; "Podcasts"; if(40.\`0\` = "Newsletter Banner"; "Newsletter Banners"; if(40.\`0\` = "Website Banner"; "Website Banners"; if(40.\`0\` = "Multi-Session Live Event"; "Multi-Session Live Events"; if(40.\`0\` = "Article"; "Articles"; if(40.\`0\` = "Ebook"; "Ebooks"; if(40.\`0\` = "Masterclass"; "Masterclasses"; 40.\`0\`)))))))))}}`
- `ioFolderName` → `[{{2.\`5\`}}] {{2.\`4\`}} {{2.\`3\`}} {{40.\`0\`}} ({{32.\`Unique ID\`}})`

#### 58 — PostgreSQL: `get_client_folder_info`
- Param 1: `{{2.\`5\`}}` (client code)
- Returns: `tla`, `client_name`, `primary_contact`, `tier1_folder_id`, `tier2_folder_id`

#### 59 — PostgreSQL: `get_product_folder_info`
- Param 1: `{{2.\`5\`}}` (client code)
- Param 2: `{{40.\`0\`}}` (product type)
- Param 3: `{{formatDate(2.\`3\`; "YYYY")}}` (year)
- Returns: `product_type_folder_id`, `year_folder_id`

#### Router 69 — Create Tier 1 if missing
- Branch 1: filter `tier1_folder_id` is empty → **Drive: Create Folder** (module 60)
  - Name: `[{{58.tla}}] {{58.client_name}}`
  - Parent: Client Projects root folder ID `1PURGWZSK1gMTJN7GDYogY1Q0_ohsUkht`
- Branch 2: pass-through placeholder

#### SetVariables 75 — Resolve Tier 1 ID *(main flow, after router 69)*
- `resolved_tier1` = `{{ifempty(58.tier1_folder_id; 60.id)}}`

#### Router 70 — Create Tier 2 if missing
- Branch 1: filter `tier2_folder_id` is empty → **Drive: Create Folder** (module 61)
  - Name: `[{{2.\`5\`}}] {{58.primary_contact}}`
  - Parent: `{{75.resolved_tier1}}`
- Branch 2: pass-through placeholder

#### SetVariables 76 — Resolve Tier 2 ID *(main flow, after router 70)*
- `resolved_tier2` = `{{ifempty(58.tier2_folder_id; 61.id)}}`

#### Router 71 — Store Tier 1+2 IDs if either was just created
- Branch 1: filter `tier1_folder_id` OR `tier2_folder_id` is empty → **PostgreSQL: `update_client_folder_ids`** (module 62)
  - Param 1: `{{2.\`5\`}}` (client code)
  - Param 2: `{{75.resolved_tier1}}`
  - Param 3: `{{76.resolved_tier2}}`
- Branch 2: pass-through placeholder

#### Router 72 — Create Tier 3 if missing
- Branch 1: filter `product_type_folder_id` is empty → **Drive: Create Folder** (module 63)
  - Name: `[{{2.\`5\`}}] {{57.tier3FolderName}}`
  - Parent: `{{76.resolved_tier2}}`
- Branch 2: pass-through placeholder

#### SetVariables 77 — Resolve Tier 3 ID *(main flow, after router 72)*
- `resolved_tier3` = `{{ifempty(59.product_type_folder_id; 63.id)}}`

#### Router 73 — Create Tier 4 if missing
- Branch 1: filter `year_folder_id` is empty → **Drive: Create Folder** (module 64)
  - Name: `{{formatDate(2.\`3\`; "YYYY")}}`
  - Parent: `{{77.resolved_tier3}}`
- Branch 2: pass-through placeholder

#### SetVariables 78 — Resolve Tier 4 ID *(main flow, after router 73)*
- `resolved_tier4` = `{{ifempty(59.year_folder_id; 64.id)}}`

#### Router 74 — Store Tier 3+4 IDs if either was just created
- Branch 1: filter `product_type_folder_id` OR `year_folder_id` is empty → **PostgreSQL: `upsert_product_folder`** (module 65)
  - Param 1: `{{2.\`5\`}}` (client code)
  - Param 2: `{{40.\`0\`}}` (product type)
  - Param 3: `{{formatDate(2.\`3\`; "YYYY")}}` (year)
  - Param 4: `{{77.resolved_tier3}}`
  - Param 5: `{{78.resolved_tier4}}`
- Branch 2: pass-through placeholder

#### 66 — Drive: Create IO Folder *(always, main flow)*
- Name: `{{57.ioFolderName}}`
- Parent: `{{78.resolved_tier4}}`

#### 67 — PostgreSQL: `upsert_io_product` *(always)*
- Param 1: `{{2.\`4\`}}` (IO reference)
- Param 2: `{{40.\`0\`}}` (product type)
- Param 3: `{{40.\`1\`}}` (product name)
- Param 4: `{{32.\`Unique ID\`}}`
- Param 5: `{{66.id}}` (Drive folder ID)

#### 68 — Google Sheets: Update Row *(always)*
- Spreadsheet: IO Submissions
- Sheet: Products
- Row: `{{17.__ROW_NUMBER__}}`
- Column E: `{{32.\`Unique ID\`}}`

---

**Also update in the main flow (outside iterator):**
- Module 41: set value to `- {{40.\`0\`}}` (product type only)
- Module 47: append to goal notes: `\n\nFull IO details: https://bionic-dashboard-aevhj.kinsta.app/dashboard/3-io-overview?io_reference={{2.\`4\`}}`
- Module 54: set `@03` param to `https://bionic-dashboard-aevhj.kinsta.app/dashboard/3-io-overview?io_reference={{2.\`4\`}}`
- Module 10: remove Drive link write-back (col S / field 18)
- Delete module 12 (old flat Drive folder creation)

---

## Drive Folder Structure

The Drive folder structure uses a four-tier hierarchy that mirrors the client and contact structure.

### Structure

```
Bitesize Bio Shared Drive/
└── Client Projects/                                          <- Root constant in Make.com
    └── [ZYM] Zymo Research/                                 <- Tier 1: Company folder
        └── [ZYM001] Karen Kao/                              <- Tier 2: Contact folder
            └── [ZYM001] eBlasts/                            <- Tier 3: Product type folder
                └── 2026/                                    <- Tier 4: Year folder
                    └── [ZYM001] IO-467110289596 2026-02-23 eBlast (a1b2c3)/  <- IO folder
```

**How each tier works:**

- **Tier 1 — Company folder** — `[TLA] Company Name`, e.g. `[ZYM] Zymo Research`. One per company; reused across all IOs for that company.
- **Tier 2 — Contact folder** — `[ClientCode] Contact Name`, e.g. `[ZYM001] Karen Kao`. One per billing contact.
- **Tier 3 — Product type folder** — `[ClientCode] eBlasts` / `[ClientCode] Live Events` etc. See product type → folder name mapping in the Product Type Routing section.
- **Tier 4 — Year folder** — year from IO signed date (e.g. `2026`). Folders can be renamed in Drive without breaking automation — IDs are tracked in the database.
- **IO folder** — `[ClientCode] [IO Ref] [Date] [ProductType] ([UUID])` — always created fresh, unique per product per IO. UUID is included to prevent name collisions when an IO contains multiple products of the same type.

**Each product on an IO gets its own complete path through all tiers.** An IO with a Live Event and an eBlast creates two separate IO folders, one under Live Events and one under eBlasts.

**All tiers use find-or-create logic:**
1. Check the database for a stored folder ID
2. If not found, search Drive by name under the parent folder
3. If still not found, create the folder
4. Store the ID in the database for future runs

The root `Client Projects` folder ID (`1PURGWZSK1gMTJN7GDYogY1Q0_ohsUkht`) is stored as a constant in Make.com. Tier 1+2 folder IDs are cached in `clients.drive_folder_id` and `bsb_client_codes.drive_folder_id`. Tier 3+4 folder IDs are cached in `client_product_folders`.

---

## Product Type Routing

Each deliverable on an IO is routed based on its product type. The table below shows which types are currently handled and which are planned:

The BsB/MF distinction is implied by the client and not included in the product type value. The Make.com router identifies MF/Leica IOs by client TLA.

| Product Type | Drive Folder Name | Status | Notes |
|---|---|---|---|
| Live Event | Live Events | Live (BsB) / Placeholder (MF) | BsB: Asana project from template + pre-filled registration URL. MF: route exists, not yet built |
| Multi-Session Live Event | Multi-Session Live Events | Not built | Separate branch planned |
| eBlast | eBlasts | Placeholder | Route exists, not yet built |
| Podcast | Podcasts | Not built | Will use Transistor platform |
| Newsletter Banner | Newsletter Banners | Not built | Planned |
| Website Banner | Website Banners | Not built | Planned |
| Article | Articles | Not built | Planned |
| Ebook | Ebooks | Not built | Planned |
| Masterclass | Masterclasses | Not built | Planned |

---

## New Client Handling

### Current Process

For the form's client code dropdown to include a new client, the salesperson (or an admin) must manually add the company and client code to the client directory Google Sheet *before* submitting the IO form.

### Planned Process

New fields will be added to the IO submission form that appear when "New Client" is selected. The salesperson fills in the company details (name, TLA, billing contact, payment terms, etc.) as part of the submission. Make.com will then automatically:

- Create the client record in the database
- Create the client code record in the database
- Add the entry to the Google Sheet so the dropdown stays current for future submissions

This removes the manual step entirely and ensures the database and Google Sheet stay in sync.

---

## The Database

The automation writes to and reads from a PostgreSQL database hosted on Sevalla. The relevant tables are:

| Table | What it stores |
|---|---|
| `insertion_orders` | One record per IO submission — salesperson details, client info, submission date, and links to Asana and Drive |
| `io_products` | One record per product per IO — product type, Drive folder ID, Asana project ID (nullable until built), unique ID |
| `clients` | Master list of companies — name, formatted name, 3-letter acronym (TLA), and Tier 1 Drive folder ID |
| `bsb_client_codes` | One record per billing contact — links to the client, stores contact details, billing info, payment terms, PO requirements, and Tier 2 Drive folder ID |
| `client_product_folders` | Tier 3+4 Drive folder ID cache — one row per unique client code + product type + year combination |

The database is the single source of truth for IO data. A Metabase view joining `insertion_orders` + `io_products` + `clients` + `bsb_client_codes` provides a complete picture of every IO, every product, and every link. The Google Sheet is input-only. Asana remains the source of truth for project management.

---

## Roadmap

### FC1 (Now to 5 April 2026)

1. Client DB reimport — complete ✅
2. Drive folder audit (Tier 1+2 folder IDs into DB) — complete ✅
3. Drive folder structure update — 4-tier find-or-create in Make.com + `io_products` table
4. New client fields on the Gravity Form and Make.com handling — designed ✅, Make.com build pending
5. Phase 2: TwentyThree Live Event creation for Live Events
6. Milestone sync 7th parameter update (quick Make.com config change)

### FC2 (13 April to 24 May 2026)

7. MF Live Event branch build-out
8. New product type branches — all remaining types in the table above
9. Reverse sync — name changes made in Asana or TwentyThree propagate back to the database
10. Metabase IO dashboard — view joining insertion_orders + io_products + clients + bsb_client_codes

---

## Background: How the Automation Is Built

The automation runs in Make.com. A scenario watches the Google Sheet for new rows (checking up to 2 new submissions per run). When a new row is detected, it follows the flow described above.

The scenario blueprint is saved at `make-blueprints/phase-1-io-submission-project-creation.json` in this repository.

The submission form is built with Gravity Forms on an internal WordPress site. In the longer term, HubSpot may replace Gravity Forms as the submission source, but the Make.com automation would largely remain the same — only the trigger would change.
