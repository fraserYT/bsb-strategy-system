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

**⚠️ Open questions (pending team confirmation):**
1. Drive folder names — for variants of the same category (e.g. both eBlast types), do they share a folder (`eBlasts`) or get separate folders?
2. "Educational Article" and "Product Article" — same `Articles` folder or separate?
3. Are the old product types (Multi-Session Live Event, Newsletter Banner, Website Banner) being retired or do they remain alongside the new list?

| Product Type | Asana Template | Drive Folder Name | Status | Notes |
|---|---|---|---|---|
| Live Event | [Template](https://app.asana.com/1/10928367000451/project/1205384033200477/list/1205386857458568) | Live Events | Live (BsB) | Asana project from template + pre-filled registration URL |
| Microscopy Focus Live Event | [Template](https://app.asana.com/1/10928367000451/project/1207443958731404/list/1207444426812531) | Live Events | Not built | MF-specific live event branch — replaces the placeholder MF route |
| Hybrid Event | [Template](https://app.asana.com/1/10928367000451/project/1210079510012368/overview/1210079519686730) | Hybrid Events | Not built | New product type |
| eBlast (Single send) | [Template](https://app.asana.com/1/10928367000451/project/1200403743441681/list/1205110749757378) | eBlasts | Placeholder (route exists) | ⚠️ Folder name TBC — shares folder with soft resend variant? |
| eBlast (with soft resend) | [Template](https://app.asana.com/1/10928367000451/project/1206488939681747/list/1206489483671058) | eBlasts | Not built | ⚠️ Folder name TBC |
| eBook (creation, hosting and promotion) | [Template](https://app.asana.com/1/10928367000451/project/1206062951814214/list/1206063886123309) | eBooks | Not built | ⚠️ Folder name TBC — shares folder with hosting-only variant? |
| eBook/downloadable (hosting and promotion only) | [Template](https://app.asana.com/1/10928367000451/project/1204522709698702/list/1204524347186660) | eBooks | Not built | ⚠️ Folder name TBC |
| Display ads campaign | [Template](https://app.asana.com/1/10928367000451/project/1208715374595062/list/1208716588057740) | Display Ad Campaigns | Not built | New product type |
| Educational Article (Client Sponsored/Written) | [Template](https://app.asana.com/1/10928367000451/project/1212360402687239/list/1212361593046347) | Articles | Not built | ⚠️ Folder name TBC — shares folder with Product Article? |
| Product Article (Client Sponsored/Written) | [Template](https://app.asana.com/1/10928367000451/project/1207642533460808/list/1207642933398192) | Articles | Not built | ⚠️ Folder name TBC |
| Masterclass email series (x7) | [Template](https://app.asana.com/1/10928367000451/project/1210035872761531/list/1210036080685782) | Masterclasses | Not built | |
| Newsletter Sponsorship 1-4x | [Template](https://app.asana.com/1/10928367000451/project/1211406171146623/list/1211408780452912) | Newsletter Sponsorships | Not built | ⚠️ Replaces "Newsletter Banner"? |
| Podcast Series | [Template](https://app.asana.com/1/10928367000451/project/1201367861618216/list/1205115756115854) | Podcasts | Not built | Will use Transistor platform |
| Multi-Session Live Event | — | Multi-Session Live Events | Not built | ⚠️ Retiring? Not in new product list |
| Website Banner | — | Website Banners | Not built | ⚠️ Retiring? Not in new product list |

---

## New Client Handling

### Current Process

For the form's client code dropdown to include a new client, the salesperson (or an admin) must manually add the company and client code to the client directory Google Sheet *before* submitting the IO form.

### Planned Process

New fields will be added to the IO submission form that appear when "New Client" is ticked. The salesperson fills in the company details (name, TLA, billing contact, payment terms, etc.) as part of the submission. Make.com will then automatically:

- Create the client record in the database (`upsert_client`)
- Create the client code record in the database (`upsert_client_code`)
- Add the entry to the client directory Google Sheet so the dropdown is current for future submissions

This removes the manual step entirely and ensures the database and Google Sheet stay in sync.

---

### New Client Flow — Implementation

#### DB changes (already deployed)

- `UNIQUE` constraint added to `clients.tla` — required for `upsert_client` ON CONFLICT
- `get_client_folder_info` now returns `primary_contact_email` as a 6th column (was 5)
  - **Important**: any existing Make.com module referencing this function by positional output must be updated if you add a column reference after `primary_contact`

---

#### Step 1 — Gravity Form changes (surveys.bitesizebio.com WP admin → Forms → IO Submission Form)

**Fix the conditional logic bug on field 8 (Other Company / Full Name):**
- Open field 8 → Conditional Logic
- Change the rule value from `New Client?` to `New Client` (remove the question mark)
- Rename the field label from "Other Company (Full Name)" to "Company Name"
- Update description to: "Enter the full legal company name."

**Make the BSB Client Code dropdown conditional (field 6):**
- Open field 6 → Conditional Logic → Enable
- Rule: `New Client` is NOT `New Client` (i.e. show when checkbox is unchecked)
- This hides the dropdown when the salesperson ticks New Client

**Make Primary Contact fields conditional (fields 10 + 11):**
- Open field 10 (Primary Client Contact) → Conditional Logic → Enable
- Rule: `New Client` is `New Client`
- Open field 11 (Primary Client Email) → same rule
- These fields now only appear when New Client is ticked

**Add new fields (all conditional: `New Client` is `New Client`):**

Add the following fields after field 8 (Company Name), before the section break (field 19):

| # | Type | Label | Required | Notes |
|---|------|-------|----------|-------|
| new | text | TLA | Yes | 3-letter company acronym, e.g. ZYM |
| new | text | New BSB Client Code | Yes | e.g. ZYM001 — TLA + 3-digit number |
| new | text | Payment Terms | No | e.g. "30 days", "Prepay" |
| new | text | PO Required | No | e.g. "Yes — required before invoicing", "No" |
| new | text | Billing Contact Name | No | |
| new | email | Billing Contact Email | No | |
| new | textarea | Billing Address | No | |

Apply conditional logic to each: show when `New Client` is `New Client`.

**Update field 7 (New Client checkbox) description to:**
> Tick this box if this client does not yet have a BSB client code. Fill in the new client details below — the system will create their record automatically on submission.

---

#### Step 2 — IO Forms Google Sheet changes

Sheet: `IO Forms` tab in the IO submissions spreadsheet (`1tQfpYsQEfpO5XAPzWbkHUJeGWPKITDiSDOhp6GGJ0jA`)

Add the following columns at the end (after column V, currently the last column):

| Column | Letter | Header |
|--------|--------|--------|
| 22 | W | TLA |
| 23 | X | New BSB Client Code |
| 24 | Y | Payment Terms |
| 25 | Z | PO Required |
| 26 | AA | Billing Contact Name |
| 27 | AB | Billing Contact Email |
| 28 | AC | Billing Address |

Ensure the GF Sheets integration maps the new form fields to these columns (check the GF Google Sheets add-on settings — field order in the form should map to column order in the sheet).

---

#### Step 3 — Client Directory Google Sheet changes

Sheet: `1hSSJCG-QR6R6XIyB-CrxryDhA3_XqBt-SqhG9Oqy96E`, tab 0

Add a new column **after** the existing columns:
- Header: `Primary contact email`

Backfill this column for existing entries if you want auto-population for existing clients in future (not required for the new client flow to work).

---

#### Step 4 — Make.com changes

**4a. Update module 2 (Google Sheets Watch Rows) tableFirstRow**
- Change `tableFirstRow` from `A1:V1` to `A1:AC1` so Make.com reads the new columns

**4b. Add a SetVariables module immediately after module 2** (new module, e.g. 79)
- Scope: `roundtrip`
- Variables:
  - `resolved_client_code` = `{{ifempty(2.\`5\`; 2.\`23\`)}}`
    *(col 5 = Formatted Client Code for existing; col 23 = New BSB Client Code for new)*
  - `resolved_company` = `{{ifempty(2.\`15\`; 2.\`7\`)}}`
    *(col 15 = Company Name auto-populated for existing; col 7 = Company Name entered for new)*
  - `resolved_formatted_company` = `{{ifempty(2.\`16\`; join(list(2.\`7\`; " ["; 2.\`22\`; "]"); ""))}}`
    *(col 16 = Formatted Company Name for existing; derived "Name [TLA]" for new)*

**4c. Add a Router module after 79** (new module, e.g. 80)

- **Branch 1** — filter: `{{2.\`6\`}}` = `New Client` (checkbox ticked)
  - **Module 81 — PostgreSQL: `upsert_client`**
    - Param 1 (tla): `{{2.\`22\`}}`
    - Param 2 (client_name): `{{2.\`7\`}}`
    - Param 3 (formatted_client_name): `{{79.resolved_formatted_company}}`
  - **Module 82 — PostgreSQL: `upsert_client_code`**
    - Param 1 (bsb_client_code): `{{2.\`23\`}}`
    - Param 2 (tla): `{{2.\`22\`}}`
    - Param 3 (primary_contact): `{{2.\`8\`}}`
    - Param 4 (primary_contact_email): `{{2.\`9\`}}`
    - Param 5 (payment_terms): `{{2.\`24\`}}`
    - Param 6 (po_required): `{{2.\`25\`}}`
    - Param 7 (billing_contact): `{{2.\`26\`}}`
    - Param 8 (billing_email): `{{2.\`27\`}}`
    - Param 9 (billing_address): `{{2.\`28\`}}`
  - **Module 83 — Google Sheets: Add a Row** (client directory sheet)
    - Spreadsheet: `1hSSJCG-QR6R6XIyB-CrxryDhA3_XqBt-SqhG9Oqy96E`
    - Sheet tab: the client directory tab (tab index 0)
    - `BsB Client Code`: `{{2.\`23\`}}`
    - `Client Name`: `{{2.\`7\`}}`
    - `Formatted Client Name`: `{{79.resolved_formatted_company}}`
    - `Primary contact`: `{{2.\`8\`}}`
    - `Primary contact email`: `{{2.\`9\`}}`

- **Branch 2** — pass-through (existing client, no action needed)

**4d. Update downstream modules that reference client code or company name:**

Replace `{{2.\`5\`}}` with `{{79.resolved_client_code}}` in:
- Module 47 (Asana goal notes — `BsB Client Code: ...`)
- Module 6 (Asana task name)
- Module 52 (upsert_insertion_order — @07)
- Module 58 (get_client_folder_info — Param 1, when 4-tier Drive flow is built)

Replace `{{2.\`15\`}}` with `{{79.resolved_company}}` in:
- Module 47 (Asana goal notes — `Client: ...`)
- Module 12 (Drive folder name)
- Module 48 (Slack message)
- Module 52 (upsert_insertion_order — @17)

Replace `{{2.\`16\`}}` with `{{79.resolved_formatted_company}}` in:
- Module 6 (Asana task name)
- Module 52 (upsert_insertion_order — @18)

---

#### Notes on Populate Anything (existing client UX)

The client code dropdown (field 6) populates from the client directory sheet:
- Label template: `{BsB Client Code} | {Client Name} | {Primary contact}`
- Value: `{BsB Client Code}`

Fields 16 (Company Name) and 18 (Formatted Company Name) auto-populate from the sheet based on the selected client code — these remain hidden and unchanged.

Fields 10 (Primary Client Contact) and 11 (Primary Client Email) are now hidden for existing clients. For existing clients, Make.com uses `get_client_folder_info` to retrieve the primary contact and email from the DB. Module 52's @10 and @11 parameters should be updated to use the DB result for existing clients:
- For now, `{{2.\`8\`}}` and `{{2.\`9\`}}` will be empty for existing client submissions (since fields 10 and 11 are hidden). The DB already has this data from the original import.
- **Option**: add a PostgreSQL `get_client_folder_info` call in Branch 2 of the router (existing client branch) and resolve primary contact/email from there into a SetVariables, then use those variables in module 52.

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
