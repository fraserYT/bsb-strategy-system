# Gravity Form Update Instructions
## Next task — start here Monday morning

---

### Form 63 — [Auto] IO Submission Form

Go to: **surveys.bitesizebio.com WP admin → Forms → [Auto] IO Submission Form → Edit**

---

**1. Field 7 (New Client checkbox) — update description**

Replace the current description with:
> Tick this box if this client does not yet have a BSB client code. Fill in the new client details below — the system will create their record automatically on submission.

---

**2. Field 6 (BSB Client Code dropdown) — add conditional logic**

- Open field 6 → Enable Conditional Logic
- Action: **Hide** this field if **All** of the following match:
  - `New Client` **is** `New Client`

---

**3. Field 8 (Other Company Full Name) — fix bug + rename**

- Rename label to: `Company Name`
- Update description to: `Enter the full legal company name.`
- Open Conditional Logic — the rule currently reads `New Client? is New Client?` — fix it to:
  - Action: **Show** this field if **All** match:
  - `New Client` **is** `New Client`

---

**4. Fields 10 & 11 — make conditional**

- Open field 10 (Primary Client Contact) → Enable Conditional Logic
  - Action: **Show** if `New Client` **is** `New Client`
- Open field 11 (Primary Client Email) → same rule

---

**5. Add 7 new fields** — place these after field 8 (Company Name), before the section break. All should have conditional logic: **Show** if `New Client` **is** `New Client`

| Label | Type | Required |
|---|---|---|
| TLA | Single line text | Yes |
| New BSB Client Code | Single line text | Yes |
| Payment Terms | Single line text | No |
| PO Required | Single line text | No |
| Billing Contact Name | Single line text | No |
| Billing Contact Email | Email | No |
| Billing Address | Paragraph text | No |

Add a description to TLA: `3-letter company acronym, e.g. ZYM`
Add a description to New BSB Client Code: `TLA + 3-digit number, e.g. ZYM001`

---

### Form 64 — [Auto] Products From IO

Go to: **Forms → [Auto] Products From IO → Edit**

Find the **Product Type** dropdown field and replace the current choices with these 14 options (value = label for each):

1. Live Event
2. Microscopy Focus Live Event
3. Hybrid Event
4. eBlast (Single send)
5. eBlast (with soft resend)
6. eBook (creation, hosting and promotion)
7. eBook/downloadable (hosting and promotion only)
8. Display ads campaign
9. Educational Article (Client Sponsored/Written)
10. Product Article (Client Sponsored/Written)
11. Masterclass email series (x7)
12. Newsletter Sponsorship 1-4x
13. Podcast Series
14. Multi-Session Live Event

---

### After completing the form changes

Once both forms are updated:

1. **IO Forms sheet** (`1tQfpYsQEfpO5XAPzWbkHUJeGWPKITDiSDOhp6GGJ0jA`) — add columns W–AC:
   - W (22): TLA
   - X (23): New BSB Client Code
   - Y (24): Payment Terms
   - Z (25): PO Required
   - AA (26): Billing Contact Name
   - AB (27): Billing Contact Email
   - AC (28): Billing Address
   - Update GF Sheets addon mapping to include these new fields

2. **Client directory sheet** (`1hSSJCG-QR6R6XIyB-CrxryDhA3_XqBt-SqhG9Oqy96E`) — add column: `Primary contact email`

3. **Make.com** — full instructions in `docs/io-automation.md` under "New Client Flow — Implementation"

4. **Deploy SQL changes to live Sevalla DB**:
   - Run `ALTER TABLE clients ADD CONSTRAINT clients_tla_unique UNIQUE (tla);` (if not already present)
   - Re-deploy `get_client_folder_info` function (now returns 6 columns including `primary_contact_email`)
