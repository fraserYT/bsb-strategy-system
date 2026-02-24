# Drive Folder Sync Report
Generated: 2026-02-24

## Summary

The Drive folder audit has been completed. All Tier 1 (client) and Tier 2 (contact) folders that follow the correct naming convention have been matched to the database.

**One rename is required** to bring the final outstanding contact folder into sync. There are also a small number of folders that need a quick decision.

---

## Action Required

### 1. Rename a contact folder — N6T (N6 Tec)

Inside the **[N6T] N6 Tec** client folder, there is a contact folder named incorrectly:

| Current name | Correct name |
|---|---|
| `[N6T] Jenny Alfrey` | `[N6T001] Jenny Alfrey` |

The folder uses the company TLA (`N6T`) instead of the full client code (`N6T001`). Please rename it in Drive.

**After renaming**, let Fraser know so the audit script can be re-run to pick up the folder ID.

---

## Decisions Needed

### 2. Zeiss (ZEI) — `The Microscopists Podcast` folder

Inside the **[ZEI] Zeiss** client folder there is a folder called `The Microscopists Podcast` sitting directly at the contact level, rather than inside a proper `[ZEI00X] Contact Name` subfolder.

**Options:**
- **Leave as-is** — if this folder is not a client contact folder and its contents don't need to be tracked in the system, no action is needed. It will simply be ignored by the automation.
- **Move it** — if the podcast work is associated with a specific Zeiss contact, move the folder's contents into the appropriate `[ZEI00X] Contact Name` subfolder.

---

## Folders to Leave As-Is

The following folders were found inside client folders but are clearly not contact folders — they are misc/archive folders and **do not need to be renamed or moved**. Please just confirm you're happy for them to be ignored by the system.

| Client | Folder name |
|--------|-------------|
| BCS | `AdHoc, Additional Information Files, CJS etc.` |
| IDT | `Misc.` |
| LGC | `Misc.` |
| MMS | `Archive [2020-2023 Projects]` |
| TFS | `Misc.` |
| UNC | `Misc.` |
| ZEI | `Misc.` |
| ZYM | `Misc.` |

---

## What's Already Done

| Tier | Description | Status |
|------|-------------|--------|
| Tier 1 | Client folders (`[TLA] Client Name`) | ✅ 46 folder IDs in database |
| Tier 2 | Contact folders (`[CODE] Contact Name`) | ✅ 78 folder IDs in database |
| Tiers 3 & 4 | Product type and year folders | Created per IO by Make.com — no retrospective audit needed |

There is also one Tier 1 archive folder (`[1] ARCHIVED/COMPLETED/OLD_PROJECTS`) which is correctly being ignored by the system.
