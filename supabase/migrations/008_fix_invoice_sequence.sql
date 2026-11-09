-- ============================================================
-- Computer Care POS - Supabase Migration
-- 008_fix_invoice_sequence.sql
--
-- Problem: POS sales get their invoice numbers inside the app, which
-- never updates the server's number_sequences row. When an online order
-- is marked as shipped, process_online_order_delivery calls
-- get_next_sequence('INVOICE'), which hands out a number already used
-- by a POS sale -> "duplicate key ... sales_invoice_number_key".
--
-- Fix: before handing out an INVOICE number, move the counter past the
-- highest invoice number that already exists in sales for this year.
-- Safe to re-run.
-- ============================================================

CREATE OR REPLACE FUNCTION get_next_sequence(p_sequence_type TEXT)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_year INTEGER;
  v_last_number INTEGER;
  v_format TEXT;
  v_current_year INTEGER;
  v_max_used INTEGER;
  v_result TEXT;
BEGIN
  v_current_year := EXTRACT(YEAR FROM NOW())::INTEGER;

  -- Lock the row to prevent concurrent issues
  SELECT prefix, current_year, last_number, format
  INTO v_prefix, v_year, v_last_number, v_format
  FROM number_sequences
  WHERE sequence_type = p_sequence_type
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sequence type % not found', p_sequence_type;
  END IF;

  -- Reset counter if year changed
  IF v_year != v_current_year THEN
    v_last_number := 0;
    v_year := v_current_year;
  END IF;

  -- Never reuse an invoice number already created by the POS app
  IF p_sequence_type = 'INVOICE' THEN
    SELECT COALESCE(MAX(
             (regexp_match(invoice_number,
                '^' || v_prefix || '-' || v_year::TEXT || '-([0-9]+)$'))[1]::INTEGER
           ), 0)
    INTO v_max_used
    FROM sales
    WHERE invoice_number LIKE v_prefix || '-' || v_year::TEXT || '-%';

    v_last_number := GREATEST(v_last_number, v_max_used);
  END IF;

  v_last_number := v_last_number + 1;

  -- Update the sequence
  UPDATE number_sequences
  SET last_number = v_last_number,
      current_year = v_year,
      updated_at = NOW()
  WHERE sequence_type = p_sequence_type;

  -- Format: {PREFIX}-{YEAR}-{NUMBER:4}
  v_result := v_prefix || '-' || v_year::TEXT || '-' || LPAD(v_last_number::TEXT, 4, '0');

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
