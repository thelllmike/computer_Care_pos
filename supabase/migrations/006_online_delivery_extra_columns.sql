-- ============================================================
-- Computer Care POS - Supabase Migration
-- 006_online_delivery_extra_columns.sql
-- Adds 4 missing columns to online_orders needed by the Flutter UI
--
-- SAFE: Only adds new columns with DEFAULT values — no data loss.
-- ============================================================

ALTER TABLE online_orders
  ADD COLUMN IF NOT EXISTS delivery_fee     DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS is_prepaid       BOOLEAN         NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS paid_amount      DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS payment_method   TEXT            NOT NULL DEFAULT 'CASH';
