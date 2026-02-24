# Drive Folder Audit — Tier 2 Report
Generated: 2026-02-24

## What This Is

Tier 2 folders are the contact-level subfolders inside each client folder, named in the format `[CODE] Contact Name` (e.g. `[ZYM001] Karen Kao`). This audit matches them to records in the `bsb_client_codes` database table and writes the Drive folder ID against each record.

This is needed so the Make.com automation can find existing folders by ID rather than searching Drive by name on every run.

---

## Status

| | Count |
|---|---|
| Ready to write to DB | **78** |
| Issues needing action (see below) | **10** |
| Already done | 0 |

---

## Action Required: Run the Script

Once the issues below are resolved, run this from the project root to write the 78 folder IDs:

```bash
python3 scripts/audit_drive_folders.py --tier2 --apply
```

(Re-run after each fix to pick up newly conforming folders.)

---

## Issues Needing Attention

These 10 folders were found inside client folders but don't match the expected `[CODE] Contact Name` format, or their code isn't in the database. Each needs a decision.

### Misc. folders (8 folders — likely OK to ignore)

These are loose/legacy folders inside client folders that don't follow the naming convention. They don't need to be in the database — just confirm they're not client contact folders that should be renamed.

| Client | Folder name | Recommended action |
|--------|-------------|-------------------|
| BCS | `AdHoc, Additional Information Files, CJS etc.` | Leave as-is — not a contact folder |
| IDT | `Misc.` | Leave as-is — not a contact folder |
| LGC | `Misc.` | Leave as-is — not a contact folder |
| MMS | `Archive [2020-2023 Projects]` | Leave as-is — old archive |
| TFS | `Misc.` | Leave as-is — not a contact folder |
| UNC | `Misc.` | Leave as-is — not a contact folder |
| ZEI | `Misc.` | Leave as-is — not a contact folder |
| ZYM | `Misc.` | Leave as-is — not a contact folder |

---

### ZEI — `The Microscopists Podcast`

A podcast folder appears to be sitting directly inside the Zeiss client folder rather than under a contact folder. **Decide:** should this be moved into a proper `[ZEI00X] Contact Name` subfolder, or is it intentionally at this level?

---

### N6T — `[N6T] Jenny Alfrey`

This folder is named using the company TLA (`[N6T]`) rather than the full client code (`[N6T001]`). It **will** match the database once renamed.

**Action:** Rename in Drive from `[N6T] Jenny Alfrey` → `[N6T001] Jenny Alfrey`

---

## After All Fixes

Re-run the audit to confirm everything is clean, then proceed to Tier 3/4 (product type and year folders — these are created per IO, so there's nothing to retrospectively audit at this stage).

```bash
python3 scripts/audit_drive_folders.py --tier2 --apply
```
