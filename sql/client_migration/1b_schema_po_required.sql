-- Client migration step 1b: change po_required to TEXT
-- Preserves full values e.g. "Yes (Coupa)", "No - but check for next order"
ALTER TABLE bsb_client_codes
    ALTER COLUMN po_required TYPE TEXT USING po_required::TEXT;
