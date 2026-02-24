-- New Client Handling Migration
-- Run on Sevalla PostgreSQL (bitesize_bio database)
-- Adds UNIQUE constraint on clients.tla and two new functions for
-- creating client + client code records from a new IO form submission.
--
-- IMPORTANT: Paste and run each block separately in Sevalla SQL studio.
-- Last updated: 2026-02-24


-- ============================================
-- STEP 1: Add UNIQUE constraint on clients.tla
-- Paste and run this block first.
-- Required for upsert_client to use ON CONFLICT (tla).
-- ============================================

ALTER TABLE clients
    ADD CONSTRAINT clients_tla_unique UNIQUE (tla);


-- ============================================
-- STEP 2: upsert_client
-- Paste and run this block alone.
-- Creates or updates a client record from form data.
-- Returns the client id (inserted or existing).
-- ============================================

CREATE OR REPLACE FUNCTION upsert_client(
    p_tla                   TEXT,
    p_client_name           TEXT,
    p_formatted_client_name TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS '
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO clients (tla, client_name, formatted_client_name)
    VALUES (
        UPPER(TRIM(p_tla)),
        TRIM(p_client_name),
        NULLIF(TRIM(p_formatted_client_name), '''')
    )
    ON CONFLICT (tla) DO UPDATE SET
        client_name           = EXCLUDED.client_name,
        formatted_client_name = COALESCE(EXCLUDED.formatted_client_name, clients.formatted_client_name)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
';


-- ============================================
-- STEP 3: upsert_client_code
-- Paste and run this block alone.
-- Creates or updates a bsb_client_codes record from form data.
-- Looks up client_id via TLA — upsert_client must run first.
-- Returns the bsb_client_codes id (inserted or existing).
-- ============================================

CREATE OR REPLACE FUNCTION upsert_client_code(
    p_bsb_client_code       TEXT,
    p_tla                   TEXT,
    p_primary_contact       TEXT    DEFAULT NULL,
    p_primary_contact_email TEXT    DEFAULT NULL,
    p_payment_terms         TEXT    DEFAULT NULL,
    p_po_required           TEXT    DEFAULT NULL,
    p_billing_contact       TEXT    DEFAULT NULL,
    p_billing_email         TEXT    DEFAULT NULL,
    p_billing_address       TEXT    DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS '
DECLARE
    v_client_id INTEGER;
    v_id        INTEGER;
BEGIN
    SELECT id INTO v_client_id
    FROM clients
    WHERE tla = UPPER(TRIM(p_tla));

    INSERT INTO bsb_client_codes (
        bsb_client_code,
        client_id,
        primary_contact,
        primary_contact_email,
        payment_terms,
        po_required,
        client_billing_contact,
        client_billing_email,
        client_billing_address
    ) VALUES (
        UPPER(TRIM(p_bsb_client_code)),
        v_client_id,
        NULLIF(TRIM(p_primary_contact), ''''),
        NULLIF(TRIM(p_primary_contact_email), ''''),
        NULLIF(TRIM(p_payment_terms), ''''),
        NULLIF(TRIM(p_po_required), ''''),
        NULLIF(TRIM(p_billing_contact), ''''),
        NULLIF(TRIM(p_billing_email), ''''),
        NULLIF(TRIM(p_billing_address), '''')
    )
    ON CONFLICT (bsb_client_code) DO UPDATE SET
        client_id              = COALESCE(EXCLUDED.client_id, bsb_client_codes.client_id),
        primary_contact        = COALESCE(EXCLUDED.primary_contact, bsb_client_codes.primary_contact),
        primary_contact_email  = COALESCE(EXCLUDED.primary_contact_email, bsb_client_codes.primary_contact_email),
        payment_terms          = COALESCE(EXCLUDED.payment_terms, bsb_client_codes.payment_terms),
        po_required            = COALESCE(EXCLUDED.po_required, bsb_client_codes.po_required),
        client_billing_contact = COALESCE(EXCLUDED.client_billing_contact, bsb_client_codes.client_billing_contact),
        client_billing_email   = COALESCE(EXCLUDED.client_billing_email, bsb_client_codes.client_billing_email),
        client_billing_address = COALESCE(EXCLUDED.client_billing_address, bsb_client_codes.client_billing_address)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
';
