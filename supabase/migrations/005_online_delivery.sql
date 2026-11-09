-- ============================================================
-- Computer Care POS - Supabase Migration
-- 005_online_delivery.sql
-- Online delivery / order management feature
--
-- SAFE: Does NOT modify any existing tables or columns.
--       All new objects are isolated under online_order* names.
-- ============================================================

-- ==================== A. DELIVERY STATUS VALUES ====================
-- Delivery status stored as TEXT (UPPER_SNAKE_CASE) — no native PG enum needed.
-- Valid values:
--   PENDING    — order received, not yet reviewed
--   CONFIRMED  — order confirmed, preparing stock
--   PACKED     — stock packed, awaiting handover to courier
--   SHIPPED    — dispatched to courier; stock deducted; sale created
--   DELIVERED  — customer confirmed receipt
--   CANCELLED  — order cancelled (no stock impact if not yet SHIPPED)
--   RETURNED   — order returned after delivery

-- ==================== B. ONLINE_ORDERS ====================

CREATE TABLE IF NOT EXISTS online_orders (
  id                TEXT PRIMARY KEY,
  order_number      TEXT NOT NULL UNIQUE,           -- e.g. ORD-2026-0001
  customer_id       TEXT REFERENCES customers(id),  -- NULL for guest customers
  customer_name     TEXT,                           -- denormalized for guests
  customer_phone    TEXT,
  customer_address  TEXT NOT NULL,                  -- delivery address
  order_date        TIMESTAMPTZ NOT NULL,
  delivery_status   TEXT NOT NULL DEFAULT 'PENDING',

  -- Financials (mirrors the sales table pattern)
  subtotal          DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  discount_amount   DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  tax_amount        DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_amount      DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_cost        DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  gross_profit      DOUBLE PRECISION NOT NULL DEFAULT 0.0,

  -- Delivery metadata
  tracking_number   TEXT,
  notes             TEXT,
  delivery_notes    TEXT,
  shipped_at        TIMESTAMPTZ,    -- set by process_online_order_delivery
  delivered_at      TIMESTAMPTZ,    -- set by mark_online_order_delivered

  -- Idempotency guards — never reset these to false once true
  stock_deducted    BOOLEAN NOT NULL DEFAULT FALSE,
  sales_created     BOOLEAN NOT NULL DEFAULT FALSE,

  -- Set by process_online_order_delivery after sale is created
  linked_sale_id    TEXT REFERENCES sales(id),

  -- Audit
  created_by        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ,
  sync_status       TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at  TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== C. ONLINE_ORDER_ITEMS ====================

CREATE TABLE IF NOT EXISTS online_order_items (
  id                TEXT PRIMARY KEY,
  online_order_id   TEXT NOT NULL REFERENCES online_orders(id) ON DELETE CASCADE,
  product_id        TEXT NOT NULL,
  quantity          INTEGER NOT NULL,
  unit_price        DOUBLE PRECISION NOT NULL,
  unit_cost         DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  discount_amount   DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_price       DOUBLE PRECISION NOT NULL,
  total_cost        DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  profit            DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ,
  sync_status       TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at  TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== D. ONLINE_ORDER_SERIALS ====================
-- One row per serial number assigned to a serialized order item.
-- Populated at order-creation time; consumed by process_online_order_delivery.

CREATE TABLE IF NOT EXISTS online_order_serials (
  id                   TEXT PRIMARY KEY,
  online_order_item_id TEXT NOT NULL REFERENCES online_order_items(id) ON DELETE CASCADE,
  serial_number_id     TEXT NOT NULL,    -- FK to serial_numbers(id)
  serial_number        TEXT NOT NULL,    -- denormalized for display
  unit_cost            DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status          TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at     TIMESTAMPTZ,
  server_updated_at    TIMESTAMPTZ
);

-- ==================== E. INDEXES ====================

CREATE INDEX idx_online_orders_customer_id     ON online_orders(customer_id);
CREATE INDEX idx_online_orders_delivery_status ON online_orders(delivery_status);
CREATE INDEX idx_online_orders_order_date      ON online_orders(order_date);
CREATE INDEX idx_online_orders_linked_sale_id  ON online_orders(linked_sale_id);

CREATE INDEX idx_online_order_items_order_id   ON online_order_items(online_order_id);
CREATE INDEX idx_online_order_items_product_id ON online_order_items(product_id);

CREATE INDEX idx_online_order_serials_item_id          ON online_order_serials(online_order_item_id);
CREATE INDEX idx_online_order_serials_serial_number_id ON online_order_serials(serial_number_id);

-- ==================== F. ROW LEVEL SECURITY ====================

ALTER TABLE online_orders        ENABLE ROW LEVEL SECURITY;
ALTER TABLE online_order_items   ENABLE ROW LEVEL SECURITY;
ALTER TABLE online_order_serials ENABLE ROW LEVEL SECURITY;

-- ONLINE_ORDERS
CREATE POLICY "online_orders_select" ON online_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "online_orders_insert" ON online_orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "online_orders_update" ON online_orders FOR UPDATE TO authenticated USING (true);
CREATE POLICY "online_orders_delete" ON online_orders FOR DELETE TO authenticated USING (true);

-- ONLINE_ORDER_ITEMS
CREATE POLICY "online_order_items_select" ON online_order_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "online_order_items_insert" ON online_order_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "online_order_items_update" ON online_order_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "online_order_items_delete" ON online_order_items FOR DELETE TO authenticated USING (true);

-- ONLINE_ORDER_SERIALS
CREATE POLICY "online_order_serials_select" ON online_order_serials FOR SELECT TO authenticated USING (true);
CREATE POLICY "online_order_serials_insert" ON online_order_serials FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "online_order_serials_update" ON online_order_serials FOR UPDATE TO authenticated USING (true);
CREATE POLICY "online_order_serials_delete" ON online_order_serials FOR DELETE TO authenticated USING (true);

-- ==================== G. AUTO-UPDATE TRIGGERS ====================
-- Reuses the update_updated_at() function already defined in 004_functions.sql.
-- online_order_serials intentionally omitted (no updated_at column, mirrors sale_serials).

CREATE TRIGGER trg_online_orders_updated_at
  BEFORE UPDATE ON online_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_online_order_items_updated_at
  BEFORE UPDATE ON online_order_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ==================== H. SYNC METADATA REGISTRATION ====================

INSERT INTO sync_metadata (id, sync_table_name)
VALUES
  (gen_random_uuid()::TEXT, 'online_orders'),
  (gen_random_uuid()::TEXT, 'online_order_items'),
  (gen_random_uuid()::TEXT, 'online_order_serials')
ON CONFLICT (sync_table_name) DO NOTHING;

-- ==================== I. NUMBER SEQUENCE SEED ====================
-- Produces numbers like: ORD-2026-0001

INSERT INTO number_sequences (id, sequence_type, prefix, current_year, last_number, format)
VALUES (
  gen_random_uuid()::TEXT,
  'ONLINE_ORDER',
  'ORD',
  EXTRACT(YEAR FROM NOW())::INTEGER,
  0,
  '{PREFIX}-{YEAR}-{NUMBER:4}'
)
ON CONFLICT (sequence_type) DO NOTHING;


-- ============================================================
-- PART J — process_online_order_delivery
-- ============================================================
-- Atomically deducts stock and creates a POS sale record for
-- the given online order.
--
-- Idempotency:
--   • stock_deducted flag prevents double-deduction.
--   • sales_created flag prevents double-sale creation.
--   • If both flags are already true the function returns
--     immediately without any writes.
--
-- Status flow enforced:
--   Input must be CONFIRMED | PACKED | SHIPPED
--   On success, status is advanced to SHIPPED (if not already).
--
-- Returns JSONB:
--   { success, already_processed, invoice_number, sale_id }
-- ============================================================

CREATE OR REPLACE FUNCTION process_online_order_delivery(
  p_online_order_id TEXT,
  p_user_id         TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_order          online_orders%ROWTYPE;
  v_item           online_order_items%ROWTYPE;
  v_serial         online_order_serials%ROWTYPE;
  v_product        products%ROWTYPE;
  v_serial_rec     serial_numbers%ROWTYPE;
  v_sale_id        TEXT;
  v_sale_item_id   TEXT;
  v_invoice_number TEXT;
  v_subtotal       DOUBLE PRECISION;
  v_total_cost     DOUBLE PRECISION;
  v_gross_profit   DOUBLE PRECISION;
BEGIN

  -- ── 1. Lock the order row ────────────────────────────────────────────────
  SELECT * INTO v_order
  FROM online_orders
  WHERE id = p_online_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Online order "%" not found', p_online_order_id;
  END IF;

  -- ── 2. Full idempotency guard ────────────────────────────────────────────
  --      If both steps are done, return without touching anything.
  IF v_order.stock_deducted AND v_order.sales_created THEN
    RETURN jsonb_build_object(
      'success',           true,
      'already_processed', true,
      'invoice_number',    (SELECT invoice_number FROM sales WHERE id = v_order.linked_sale_id),
      'sale_id',           v_order.linked_sale_id
    );
  END IF;

  -- ── 3. Validate delivery status ──────────────────────────────────────────
  IF v_order.delivery_status NOT IN ('CONFIRMED', 'PACKED', 'SHIPPED') THEN
    RAISE EXCEPTION
      'Cannot process order "%" in status "%" — must be CONFIRMED, PACKED, or SHIPPED',
      p_online_order_id, v_order.delivery_status;
  END IF;

  -- ── 4. STOCK DEDUCTION (guarded by stock_deducted flag) ──────────────────
  --      For serialized items: update serial status → SOLD + create history.
  --      For non-serialized:   decrement inventory.quantity_on_hand.
  IF NOT v_order.stock_deducted THEN

    FOR v_item IN
      SELECT * FROM online_order_items WHERE online_order_id = p_online_order_id
    LOOP
      SELECT * INTO v_product FROM products WHERE id = v_item.product_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Product "%" not found', v_item.product_id;
      END IF;

      IF v_product.requires_serial THEN
        -- ── Serialized path: one-by-one serial processing ─────────────────
        FOR v_serial IN
          SELECT * FROM online_order_serials WHERE online_order_item_id = v_item.id
        LOOP
          -- Lock serial row to prevent concurrent use
          SELECT * INTO v_serial_rec
          FROM serial_numbers
          WHERE id = v_serial.serial_number_id
          FOR UPDATE;

          IF NOT FOUND THEN
            RAISE EXCEPTION 'Serial number record "%" not found (serial: "%")',
              v_serial.serial_number_id, v_serial.serial_number;
          END IF;

          IF v_serial_rec.status != 'IN_STOCK' THEN
            RAISE EXCEPTION
              'Serial "%" cannot be sold — current status is "%" (expected IN_STOCK)',
              v_serial.serial_number, v_serial_rec.status;
          END IF;

          -- Mark serial as SOLD (sale_id linked after sale creation below)
          UPDATE serial_numbers
          SET status = 'SOLD', updated_at = NOW()
          WHERE id = v_serial.serial_number_id;

          -- Deduct one unit from inventory
          UPDATE inventory
          SET quantity_on_hand = quantity_on_hand - 1, updated_at = NOW()
          WHERE product_id = v_item.product_id;

          -- Record the status transition
          INSERT INTO serial_number_history (
            id, serial_number_id, from_status, to_status,
            reference_type, reference_id, notes, created_by,
            created_at, sync_status
          ) VALUES (
            gen_random_uuid()::TEXT,
            v_serial.serial_number_id,
            'IN_STOCK',
            'SOLD',
            'ONLINE_ORDER',
            p_online_order_id,
            'Dispatched via online order ' || v_order.order_number,
            p_user_id,
            NOW(),
            'SYNCED'
          );
        END LOOP;

      ELSE
        -- ── Non-serialized path: bulk inventory deduction ─────────────────
        UPDATE inventory
        SET quantity_on_hand = quantity_on_hand - v_item.quantity, updated_at = NOW()
        WHERE product_id = v_item.product_id;
      END IF;

    END LOOP; -- items

    -- Persist deduction flag
    UPDATE online_orders
    SET stock_deducted = TRUE, updated_at = NOW()
    WHERE id = p_online_order_id;

    v_order.stock_deducted := TRUE;
  END IF; -- stock_deducted guard

  -- ── 5. SALE CREATION (guarded by sales_created flag) ─────────────────────
  IF NOT v_order.sales_created THEN
    v_invoice_number := get_next_sequence('INVOICE');
    v_sale_id        := gen_random_uuid()::TEXT;

    -- Aggregate totals from items (source of truth)
    SELECT
      COALESCE(SUM(total_price), 0.0),
      COALESCE(SUM(total_cost),  0.0),
      COALESCE(SUM(profit),      0.0)
    INTO v_subtotal, v_total_cost, v_gross_profit
    FROM online_order_items
    WHERE online_order_id = p_online_order_id;

    -- Create the sale record (paid in full — not credit)
    INSERT INTO sales (
      id, invoice_number, customer_id,
      sale_date, subtotal, discount_amount, tax_amount,
      total_amount, paid_amount, total_cost, gross_profit,
      is_credit, status, notes, created_by,
      created_at, sync_status
    ) VALUES (
      v_sale_id, v_invoice_number, v_order.customer_id,
      NOW(), v_subtotal, v_order.discount_amount, v_order.tax_amount,
      v_order.total_amount, v_order.total_amount, v_total_cost, v_gross_profit,
      FALSE, 'COMPLETED', v_order.notes, p_user_id,
      NOW(), 'SYNCED'
    );

    -- Create sale items and, for serialized products, sale_serials
    FOR v_item IN
      SELECT * FROM online_order_items WHERE online_order_id = p_online_order_id
    LOOP
      v_sale_item_id := gen_random_uuid()::TEXT;

      INSERT INTO sale_items (
        id, sale_id, product_id, quantity,
        unit_price, unit_cost, discount_amount,
        total_price, total_cost, profit,
        created_at, sync_status
      ) VALUES (
        v_sale_item_id, v_sale_id, v_item.product_id, v_item.quantity,
        v_item.unit_price, v_item.unit_cost, v_item.discount_amount,
        v_item.total_price, v_item.total_cost, v_item.profit,
        NOW(), 'SYNCED'
      );

      -- Insert sale_serials (no-op for non-serialized items — SELECT returns nothing)
      INSERT INTO sale_serials (
        id, sale_item_id, serial_number_id, serial_number, unit_cost,
        created_at, sync_status
      )
      SELECT
        gen_random_uuid()::TEXT,
        v_sale_item_id,
        oos.serial_number_id,
        oos.serial_number,
        oos.unit_cost,
        NOW(),
        'SYNCED'
      FROM online_order_serials oos
      WHERE oos.online_order_item_id = v_item.id;

      -- Link serial_numbers rows to the new sale and customer
      UPDATE serial_numbers
      SET
        sale_id     = v_sale_id,
        customer_id = v_order.customer_id,
        updated_at  = NOW()
      WHERE id IN (
        SELECT serial_number_id
        FROM online_order_serials
        WHERE online_order_item_id = v_item.id
      );

    END LOOP; -- items (sale creation)

    -- Persist creation flags
    UPDATE online_orders
    SET
      sales_created  = TRUE,
      linked_sale_id = v_sale_id,
      updated_at     = NOW()
    WHERE id = p_online_order_id;

  ELSE
    -- Already created; retrieve the existing invoice number
    SELECT invoice_number INTO v_invoice_number
    FROM sales WHERE id = v_order.linked_sale_id;
    v_sale_id := v_order.linked_sale_id;
  END IF; -- sales_created guard

  -- ── 6. Advance status to SHIPPED ─────────────────────────────────────────
  --      Skipped if already SHIPPED / DELIVERED / CANCELLED / RETURNED.
  UPDATE online_orders
  SET
    delivery_status = 'SHIPPED',
    shipped_at      = COALESCE(shipped_at, NOW()),
    updated_at      = NOW()
  WHERE id = p_online_order_id
    AND delivery_status NOT IN ('SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED');

  RETURN jsonb_build_object(
    'success',           true,
    'already_processed', false,
    'invoice_number',    v_invoice_number,
    'sale_id',           v_sale_id
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'process_online_order_delivery failed for order "%": %',
      p_online_order_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- PART K — mark_online_order_delivered
-- ============================================================
-- Marks a SHIPPED order as DELIVERED once the customer has
-- physically received the goods. Idempotent — safe to call twice.
--
-- Preconditions:
--   • delivery_status must be SHIPPED (i.e., process_online_order_delivery
--     must have been called first).
--   • stock_deducted = TRUE and sales_created = TRUE.
--
-- Returns JSONB:
--   { success, already_delivered, delivered_at }
-- ============================================================

CREATE OR REPLACE FUNCTION mark_online_order_delivered(
  p_online_order_id TEXT,
  p_user_id         TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_order online_orders%ROWTYPE;
  v_now   TIMESTAMPTZ := NOW();
BEGIN

  -- Lock the order row
  SELECT * INTO v_order
  FROM online_orders
  WHERE id = p_online_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Online order "%" not found', p_online_order_id;
  END IF;

  -- Idempotency: already DELIVERED
  IF v_order.delivery_status = 'DELIVERED' THEN
    RETURN jsonb_build_object(
      'success',           true,
      'already_delivered', true,
      'delivered_at',      v_order.delivered_at
    );
  END IF;

  -- Must be SHIPPED before confirming delivery
  IF v_order.delivery_status != 'SHIPPED' THEN
    RAISE EXCEPTION
      'Order "%" must be SHIPPED before marking delivered (current status: "%"). Call process_online_order_delivery first.',
      p_online_order_id, v_order.delivery_status;
  END IF;

  -- Safety: ensure delivery was fully processed (guards against data inconsistency)
  IF NOT v_order.stock_deducted OR NOT v_order.sales_created THEN
    RAISE EXCEPTION
      'Order "%" is not fully processed (stock_deducted=%, sales_created=%). Call process_online_order_delivery first.',
      p_online_order_id, v_order.stock_deducted, v_order.sales_created;
  END IF;

  -- Confirm delivery
  UPDATE online_orders
  SET
    delivery_status = 'DELIVERED',
    delivered_at    = v_now,
    updated_at      = v_now
  WHERE id = p_online_order_id;

  RETURN jsonb_build_object(
    'success',           true,
    'already_delivered', false,
    'delivered_at',      v_now
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'mark_online_order_delivered failed for order "%": %',
      p_online_order_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
