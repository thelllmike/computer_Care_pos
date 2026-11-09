-- ============================================================
-- Computer Care POS - Supabase Migration
-- 009_wholesale_price.sql
--
-- Adds an optional wholesale price per product. 0 = no wholesale price
-- (the POS then uses the normal selling price in wholesale mode).
-- Safe to re-run.
-- ============================================================

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS wholesale_price DOUBLE PRECISION NOT NULL DEFAULT 0;

-- Reload PostgREST schema cache so the app can use the new column at once
NOTIFY pgrst, 'reload schema';
