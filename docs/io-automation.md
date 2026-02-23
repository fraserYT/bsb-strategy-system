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

1. **Race condition on the database insert** — The database insert currently runs in parallel with the project creation flow. This means it may run before the Asana and Drive links have been created, so those fields can end up blank in the database. The fix is to move the database insert to run after the links are written, so it captures the actual values.

2. **Links not updated in the database** — A follow-up step to update the database record with the final Asana and Drive links is designed but not yet wired in.

3. **Additional contacts formatting** — A bug with carriage return characters in the additional contacts field is causing issues with JSON encoding. This is outstanding.

4. **Milestone sync parameter** — A pending update across all milestone sync modules to add a new tagging parameter. The database function is already deployed; the Make.com configuration just needs updating.

---

## Drive Folder Structure

The Drive folder structure is being updated from a flat layout to a four-tier hierarchy that mirrors the client and contact structure.

### New Structure

```
Bitesize Bio Shared Drive/
└── Projects/
    └── Client Projects/
        └── [ZYM] Zymo Research/                              <- Company folder
            └── [ZYM001] Karen Kao/                           <- Contact folder
                └── [ZYM001] eBlasts/                         <- Category folder
                    └── 2026/                                  <- Year folder
                        └── [ZYM001] [IO Ref] Date Project/   <- IO folder
```

**How each tier works:**

- **Company folder** — named with the 3-letter company acronym (TLA) and the full company name, e.g. `[ZYM] Zymo Research`. Created once per company; subsequent IOs for the same company reuse the existing folder.
- **Contact folder** — named with the client code and contact name, e.g. `[ZYM001] Karen Kao`. One per billing contact.
- **Category folder** — groups IOs by product category (e.g. eBlasts, Webinars). For eBlasts and Webinars, the year is the year of the event, not the IO date.
- **IO folder** — the specific folder for this IO, named with the client code, IO reference, date, and project name.

Folder creation is split by the **New Client** flag on the form:

- **New client** — create all tiers top-down, none exist yet
- **Existing client** — Tier 1 and Tier 2 already exist; search for them to get their folder IDs, then proceed downward
- **Tier 3 (category) and Year folder** — always find-or-create, even for returning clients (they may not have had this product type or year before)
- **Tier 4 (IO folder)** — always create, it is unique per IO

This avoids the need for full find-or-create logic at every tier and keeps the Make.com flow straightforward. The root folder ID for `Client Projects` in the Shared Drive is stored as a constant in Make.com.

---

## Product Type Routing

Each deliverable on an IO is routed based on its product type. The table below shows which types are currently handled and which are planned:

| Product Type | Status | Notes |
|---|---|---|
| Live Event (BsB) | Live | Asana project duplicated from template; pre-filled registration URL generated |
| Live Event (MF/Leica) | Placeholder | Route exists but not yet built |
| Multi-Session Live Event | Not built | Separate branch planned |
| eBlast | Not built | Placeholder in place |
| Podcast | Not built | Will use Transistor platform |
| Newsletter Banner | Not built | Planned |
| Website Banner | Not built | Planned |
| Article | Not built | Planned |
| Ebook | Not built | Planned |
| Masterclass | Not built | Planned |
| MF Webinar | Not built | Planned |

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
| `insertion_orders` | One record per IO submission — salesperson details, client info, product type, submission date, and links to Asana and Drive |
| `clients` | Master list of companies — name, formatted name, and 3-letter acronym (TLA) |
| `bsb_client_codes` | One record per billing contact — links to the client, stores contact details, billing info, payment terms, and PO requirements |

The database is the reporting layer. Metabase dashboards can query it to show things like IO volume over time, which clients have the most active projects, and which product types are most common. It is not a replacement for Asana — Asana remains the source of truth for project management.

---

## Roadmap

### FC1 (Now to 5 April 2026)

1. Client DB reimport — complete
2. Drive folder structure update — 4-tier, find-or-create logic
3. New client fields on the Gravity Form and Make.com handling
4. Phase 2: TwentyThree webinar creation for Live Events
5. Milestone sync parameter update (quick Make.com config change)

### FC2 (13 April to 24 May 2026)

6. MF Live Event branch build-out
7. New product type branches — all remaining types in the table above
8. Reverse sync — name changes made in Asana or TwentyThree propagate back to the database

---

## Background: How the Automation Is Built

The automation runs in Make.com. A scenario watches the Google Sheet for new rows (checking up to 2 new submissions per run). When a new row is detected, it follows the flow described above.

The scenario blueprint is saved at `make-blueprints/phase-1-io-submission-project-creation.json` in this repository.

The submission form is built with Gravity Forms on an internal WordPress site. In the longer term, HubSpot may replace Gravity Forms as the submission source, but the Make.com automation would largely remain the same — only the trigger would change.
