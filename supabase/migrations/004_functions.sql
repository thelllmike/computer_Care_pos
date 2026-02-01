-- ============================================================
-- Computer Care POS - Supabase Migration
-- 004_functions.sql
-- Database functions and triggers
-- ============================================================

-- ==================== AUTO-UPDATE updated_at ====================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all main tables
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_inventory_updated_at BEFORE UPDATE ON inventory FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_serial_numbers_updated_at BEFORE UPDATE ON serial_numbers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_purchase_orders_updated_at BEFORE UPDATE ON purchase_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_purchase_order_items_updated_at BEFORE UPDATE ON purchase_order_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_grn_updated_at BEFORE UPDATE ON grn FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_grn_items_updated_at BEFORE UPDATE ON grn_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_sale_items_updated_at BEFORE UPDATE ON sale_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_payments_updated_at BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_quotations_updated_at BEFORE UPDATE ON quotations FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_quotation_items_updated_at BEFORE UPDATE ON quotation_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_repair_jobs_updated_at BEFORE UPDATE ON repair_jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_repair_parts_updated_at BEFORE UPDATE ON repair_parts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_expenses_updated_at BEFORE UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_stock_losses_updated_at BEFORE UPDATE ON stock_losses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_warranty_claims_updated_at BEFORE UPDATE ON warranty_claims FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ==================== NEXT SEQUENCE NUMBER ====================

CREATE OR REPLACE FUNCTION get_next_sequence(p_sequence_type TEXT)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_year INTEGER;
  v_last_number INTEGER;
  v_format TEXT;
  v_current_year INTEGER;
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

-- ==================== SEED NUMBER SEQUENCES ====================

INSERT INTO number_sequences (id, sequence_type, prefix, current_year, last_number, format)
VALUES
  (gen_random_uuid()::TEXT, 'INVOICE', 'INV', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'QUOTATION', 'QTN', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'PO', 'PO', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'GRN', 'GRN', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'REPAIR_JOB', 'RPR', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'CUSTOMER', 'C', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'SUPPLIER', 'S', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'PRODUCT', 'P', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'EXPENSE', 'EXP', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'STOCK_LOSS', 'LOSS', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}'),
  (gen_random_uuid()::TEXT, 'WARRANTY_CLAIM', 'WC', EXTRACT(YEAR FROM NOW())::INTEGER, 0, '{PREFIX}-{YEAR}-{NUMBER:4}')
ON CONFLICT (sequence_type) DO NOTHING;

-- ==================== DASHBOARD VIEWS ====================

-- Daily sales summary
CREATE OR REPLACE VIEW v_daily_sales_summary AS
SELECT
  DATE(sale_date) AS sale_day,
  COUNT(*) AS total_sales,
  SUM(total_amount) AS total_revenue,
  SUM(total_cost) AS total_cost,
  SUM(gross_profit) AS total_profit,
  SUM(paid_amount) AS total_paid,
  SUM(total_amount - paid_amount) AS total_outstanding,
  COUNT(*) FILTER (WHERE is_credit = TRUE) AS credit_sales_count
FROM sales
WHERE status != 'RETURNED'
GROUP BY DATE(sale_date)
ORDER BY sale_day DESC;

-- Product stock summary
CREATE OR REPLACE VIEW v_product_stock AS
SELECT
  p.id AS product_id,
  p.code,
  p.name,
  p.product_type,
  p.selling_price,
  p.weighted_avg_cost,
  COALESCE(i.quantity_on_hand, 0) AS quantity_on_hand,
  COALESCE(i.reserved_quantity, 0) AS reserved_quantity,
  COALESCE(i.quantity_on_hand, 0) - COALESCE(i.reserved_quantity, 0) AS available_quantity,
  p.reorder_level,
  CASE WHEN COALESCE(i.quantity_on_hand, 0) <= p.reorder_level THEN TRUE ELSE FALSE END AS needs_reorder
FROM products p
LEFT JOIN inventory i ON i.product_id = p.id
WHERE p.is_active = TRUE;

-- Customer credit summary
CREATE OR REPLACE VIEW v_customer_credits AS
SELECT
  c.id AS customer_id,
  c.code,
  c.name,
  c.phone,
  c.credit_limit,
  c.credit_balance,
  c.credit_limit - c.credit_balance AS available_credit,
  COUNT(s.id) AS total_credit_sales,
  MAX(s.sale_date) AS last_credit_sale
FROM customers c
LEFT JOIN sales s ON s.customer_id = c.id AND s.is_credit = TRUE
WHERE c.credit_enabled = TRUE AND c.is_active = TRUE
GROUP BY c.id, c.code, c.name, c.phone, c.credit_limit, c.credit_balance;

-- Repair jobs active
CREATE OR REPLACE VIEW v_active_repairs AS
SELECT
  rj.*,
  c.name AS customer_name,
  c.phone AS customer_phone
FROM repair_jobs rj
LEFT JOIN customers c ON c.id = rj.customer_id
WHERE rj.status NOT IN ('DELIVERED', 'CANCELLED')
ORDER BY rj.received_date DESC;

-- ==================== REALTIME SUBSCRIPTIONS ====================
-- Enable realtime for key tables (optional - enable in Supabase dashboard)

-- ALTER PUBLICATION supabase_realtime ADD TABLE sales;
-- ALTER PUBLICATION supabase_realtime ADD TABLE inventory;
-- ALTER PUBLICATION supabase_realtime ADD TABLE repair_jobs;
-- ALTER PUBLICATION supabase_realtime ADD TABLE quotations;
