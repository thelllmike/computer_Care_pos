-- ============================================================
-- Computer Care POS - Supabase Migration
-- 007_add_missing_foreign_keys.sql
--
-- Adds FK constraints omitted from 005_online_delivery.sql.
-- SAFE: each ALTER TABLE is wrapped in a DO block that checks
-- for the constraint before adding it — idempotent, re-runnable.
-- ============================================================

-- ── 1. online_order_items.product_id → products.id ───────────────
--    Required for PostgREST to resolve the relationship and for
--    data-integrity enforcement at the DB level.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema     = 'public'
      AND table_name       = 'online_order_items'
      AND constraint_name  = 'fk_online_order_items_product_id'
  ) THEN
    ALTER TABLE public.online_order_items
      ADD CONSTRAINT fk_online_order_items_product_id
      FOREIGN KEY (product_id)
      REFERENCES public.products(id);
  END IF;
END $$;

-- ── 2. online_order_serials.serial_number_id → serial_numbers.id ─
--    Comment in 005 said "FK to serial_numbers(id)" but the
--    REFERENCES clause was never written.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema     = 'public'
      AND table_name       = 'online_order_serials'
      AND constraint_name  = 'fk_online_order_serials_serial_number_id'
  ) THEN
    ALTER TABLE public.online_order_serials
      ADD CONSTRAINT fk_online_order_serials_serial_number_id
      FOREIGN KEY (serial_number_id)
      REFERENCES public.serial_numbers(id);
  END IF;
END $$;

-- ── 3. online_orders.customer_id → customers.id ──────────────────
--    Should have been created by 005 (REFERENCES clause was present).
--    This block is a safety net in case the table was recreated.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema     = 'public'
      AND table_name       = 'online_orders'
      AND constraint_name  = 'online_orders_customer_id_fkey'
  ) THEN
    ALTER TABLE public.online_orders
      ADD CONSTRAINT online_orders_customer_id_fkey
      FOREIGN KEY (customer_id)
      REFERENCES public.customers(id);
  END IF;
END $$;

-- ── 4. online_orders.linked_sale_id → sales.id ───────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema     = 'public'
      AND table_name       = 'online_orders'
      AND constraint_name  = 'online_orders_linked_sale_id_fkey'
  ) THEN
    ALTER TABLE public.online_orders
      ADD CONSTRAINT online_orders_linked_sale_id_fkey
      FOREIGN KEY (linked_sale_id)
      REFERENCES public.sales(id);
  END IF;
END $$;

-- ── 5. Reload PostgREST schema cache ─────────────────────────────
NOTIFY pgrst, 'reload schema';
