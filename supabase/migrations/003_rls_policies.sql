-- ============================================================
-- Computer Care POS - Supabase Migration
-- 003_rls_policies.sql
-- Row Level Security policies
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE serial_numbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE serial_number_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn_serials ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_serials ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_losses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_claim_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE number_sequences ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Authenticated users can read/write all data
-- Adjust these policies based on your auth requirements
-- ============================================================

-- Helper: Create standard CRUD policies for a table
-- All authenticated users get full access (single-store POS)

-- USERS
CREATE POLICY "users_select" ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert" ON users FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "users_update" ON users FOR UPDATE TO authenticated USING (true);
CREATE POLICY "users_delete" ON users FOR DELETE TO authenticated USING (true);

-- CATEGORIES
CREATE POLICY "categories_select" ON categories FOR SELECT TO authenticated USING (true);
CREATE POLICY "categories_insert" ON categories FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "categories_update" ON categories FOR UPDATE TO authenticated USING (true);
CREATE POLICY "categories_delete" ON categories FOR DELETE TO authenticated USING (true);

-- PRODUCTS
CREATE POLICY "products_select" ON products FOR SELECT TO authenticated USING (true);
CREATE POLICY "products_insert" ON products FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "products_update" ON products FOR UPDATE TO authenticated USING (true);
CREATE POLICY "products_delete" ON products FOR DELETE TO authenticated USING (true);

-- CUSTOMERS
CREATE POLICY "customers_select" ON customers FOR SELECT TO authenticated USING (true);
CREATE POLICY "customers_insert" ON customers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "customers_update" ON customers FOR UPDATE TO authenticated USING (true);
CREATE POLICY "customers_delete" ON customers FOR DELETE TO authenticated USING (true);

-- SUPPLIERS
CREATE POLICY "suppliers_select" ON suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY "suppliers_insert" ON suppliers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "suppliers_update" ON suppliers FOR UPDATE TO authenticated USING (true);
CREATE POLICY "suppliers_delete" ON suppliers FOR DELETE TO authenticated USING (true);

-- INVENTORY
CREATE POLICY "inventory_select" ON inventory FOR SELECT TO authenticated USING (true);
CREATE POLICY "inventory_insert" ON inventory FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "inventory_update" ON inventory FOR UPDATE TO authenticated USING (true);
CREATE POLICY "inventory_delete" ON inventory FOR DELETE TO authenticated USING (true);

-- SERIAL NUMBERS
CREATE POLICY "serial_numbers_select" ON serial_numbers FOR SELECT TO authenticated USING (true);
CREATE POLICY "serial_numbers_insert" ON serial_numbers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "serial_numbers_update" ON serial_numbers FOR UPDATE TO authenticated USING (true);
CREATE POLICY "serial_numbers_delete" ON serial_numbers FOR DELETE TO authenticated USING (true);

-- SERIAL NUMBER HISTORY
CREATE POLICY "serial_number_history_select" ON serial_number_history FOR SELECT TO authenticated USING (true);
CREATE POLICY "serial_number_history_insert" ON serial_number_history FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "serial_number_history_update" ON serial_number_history FOR UPDATE TO authenticated USING (true);
CREATE POLICY "serial_number_history_delete" ON serial_number_history FOR DELETE TO authenticated USING (true);

-- PURCHASE ORDERS
CREATE POLICY "purchase_orders_select" ON purchase_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "purchase_orders_insert" ON purchase_orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "purchase_orders_update" ON purchase_orders FOR UPDATE TO authenticated USING (true);
CREATE POLICY "purchase_orders_delete" ON purchase_orders FOR DELETE TO authenticated USING (true);

-- PURCHASE ORDER ITEMS
CREATE POLICY "purchase_order_items_select" ON purchase_order_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "purchase_order_items_insert" ON purchase_order_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "purchase_order_items_update" ON purchase_order_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "purchase_order_items_delete" ON purchase_order_items FOR DELETE TO authenticated USING (true);

-- GRN
CREATE POLICY "grn_select" ON grn FOR SELECT TO authenticated USING (true);
CREATE POLICY "grn_insert" ON grn FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "grn_update" ON grn FOR UPDATE TO authenticated USING (true);
CREATE POLICY "grn_delete" ON grn FOR DELETE TO authenticated USING (true);

-- GRN ITEMS
CREATE POLICY "grn_items_select" ON grn_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "grn_items_insert" ON grn_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "grn_items_update" ON grn_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "grn_items_delete" ON grn_items FOR DELETE TO authenticated USING (true);

-- GRN SERIALS
CREATE POLICY "grn_serials_select" ON grn_serials FOR SELECT TO authenticated USING (true);
CREATE POLICY "grn_serials_insert" ON grn_serials FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "grn_serials_update" ON grn_serials FOR UPDATE TO authenticated USING (true);
CREATE POLICY "grn_serials_delete" ON grn_serials FOR DELETE TO authenticated USING (true);

-- SALES
CREATE POLICY "sales_select" ON sales FOR SELECT TO authenticated USING (true);
CREATE POLICY "sales_insert" ON sales FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "sales_update" ON sales FOR UPDATE TO authenticated USING (true);
CREATE POLICY "sales_delete" ON sales FOR DELETE TO authenticated USING (true);

-- SALE ITEMS
CREATE POLICY "sale_items_select" ON sale_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "sale_items_insert" ON sale_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "sale_items_update" ON sale_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "sale_items_delete" ON sale_items FOR DELETE TO authenticated USING (true);

-- SALE SERIALS
CREATE POLICY "sale_serials_select" ON sale_serials FOR SELECT TO authenticated USING (true);
CREATE POLICY "sale_serials_insert" ON sale_serials FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "sale_serials_update" ON sale_serials FOR UPDATE TO authenticated USING (true);
CREATE POLICY "sale_serials_delete" ON sale_serials FOR DELETE TO authenticated USING (true);

-- PAYMENTS
CREATE POLICY "payments_select" ON payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "payments_insert" ON payments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "payments_update" ON payments FOR UPDATE TO authenticated USING (true);
CREATE POLICY "payments_delete" ON payments FOR DELETE TO authenticated USING (true);

-- QUOTATIONS
CREATE POLICY "quotations_select" ON quotations FOR SELECT TO authenticated USING (true);
CREATE POLICY "quotations_insert" ON quotations FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "quotations_update" ON quotations FOR UPDATE TO authenticated USING (true);
CREATE POLICY "quotations_delete" ON quotations FOR DELETE TO authenticated USING (true);

-- QUOTATION ITEMS
CREATE POLICY "quotation_items_select" ON quotation_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "quotation_items_insert" ON quotation_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "quotation_items_update" ON quotation_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "quotation_items_delete" ON quotation_items FOR DELETE TO authenticated USING (true);

-- CREDIT TRANSACTIONS
CREATE POLICY "credit_transactions_select" ON credit_transactions FOR SELECT TO authenticated USING (true);
CREATE POLICY "credit_transactions_insert" ON credit_transactions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "credit_transactions_update" ON credit_transactions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "credit_transactions_delete" ON credit_transactions FOR DELETE TO authenticated USING (true);

-- REPAIR JOBS
CREATE POLICY "repair_jobs_select" ON repair_jobs FOR SELECT TO authenticated USING (true);
CREATE POLICY "repair_jobs_insert" ON repair_jobs FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "repair_jobs_update" ON repair_jobs FOR UPDATE TO authenticated USING (true);
CREATE POLICY "repair_jobs_delete" ON repair_jobs FOR DELETE TO authenticated USING (true);

-- REPAIR PARTS
CREATE POLICY "repair_parts_select" ON repair_parts FOR SELECT TO authenticated USING (true);
CREATE POLICY "repair_parts_insert" ON repair_parts FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "repair_parts_update" ON repair_parts FOR UPDATE TO authenticated USING (true);
CREATE POLICY "repair_parts_delete" ON repair_parts FOR DELETE TO authenticated USING (true);

-- REPAIR STATUS HISTORY
CREATE POLICY "repair_status_history_select" ON repair_status_history FOR SELECT TO authenticated USING (true);
CREATE POLICY "repair_status_history_insert" ON repair_status_history FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "repair_status_history_update" ON repair_status_history FOR UPDATE TO authenticated USING (true);
CREATE POLICY "repair_status_history_delete" ON repair_status_history FOR DELETE TO authenticated USING (true);

-- EXPENSES
CREATE POLICY "expenses_select" ON expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "expenses_insert" ON expenses FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "expenses_update" ON expenses FOR UPDATE TO authenticated USING (true);
CREATE POLICY "expenses_delete" ON expenses FOR DELETE TO authenticated USING (true);

-- STOCK LOSSES
CREATE POLICY "stock_losses_select" ON stock_losses FOR SELECT TO authenticated USING (true);
CREATE POLICY "stock_losses_insert" ON stock_losses FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "stock_losses_update" ON stock_losses FOR UPDATE TO authenticated USING (true);
CREATE POLICY "stock_losses_delete" ON stock_losses FOR DELETE TO authenticated USING (true);

-- WARRANTY CLAIMS
CREATE POLICY "warranty_claims_select" ON warranty_claims FOR SELECT TO authenticated USING (true);
CREATE POLICY "warranty_claims_insert" ON warranty_claims FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "warranty_claims_update" ON warranty_claims FOR UPDATE TO authenticated USING (true);
CREATE POLICY "warranty_claims_delete" ON warranty_claims FOR DELETE TO authenticated USING (true);

-- WARRANTY CLAIM HISTORY
CREATE POLICY "warranty_claim_history_select" ON warranty_claim_history FOR SELECT TO authenticated USING (true);
CREATE POLICY "warranty_claim_history_insert" ON warranty_claim_history FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "warranty_claim_history_update" ON warranty_claim_history FOR UPDATE TO authenticated USING (true);
CREATE POLICY "warranty_claim_history_delete" ON warranty_claim_history FOR DELETE TO authenticated USING (true);

-- AUDIT LOGS
CREATE POLICY "audit_logs_select" ON audit_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "audit_logs_insert" ON audit_logs FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "audit_logs_update" ON audit_logs FOR UPDATE TO authenticated USING (true);
CREATE POLICY "audit_logs_delete" ON audit_logs FOR DELETE TO authenticated USING (true);

-- NUMBER SEQUENCES
CREATE POLICY "number_sequences_select" ON number_sequences FOR SELECT TO authenticated USING (true);
CREATE POLICY "number_sequences_insert" ON number_sequences FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "number_sequences_update" ON number_sequences FOR UPDATE TO authenticated USING (true);
CREATE POLICY "number_sequences_delete" ON number_sequences FOR DELETE TO authenticated USING (true);

-- SYNC METADATA
CREATE POLICY "sync_metadata_select" ON sync_metadata FOR SELECT TO authenticated USING (true);
CREATE POLICY "sync_metadata_insert" ON sync_metadata FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "sync_metadata_update" ON sync_metadata FOR UPDATE TO authenticated USING (true);
CREATE POLICY "sync_metadata_delete" ON sync_metadata FOR DELETE TO authenticated USING (true);

-- SYNC QUEUE
CREATE POLICY "sync_queue_select" ON sync_queue FOR SELECT TO authenticated USING (true);
CREATE POLICY "sync_queue_insert" ON sync_queue FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "sync_queue_update" ON sync_queue FOR UPDATE TO authenticated USING (true);
CREATE POLICY "sync_queue_delete" ON sync_queue FOR DELETE TO authenticated USING (true);

-- APP SETTINGS
CREATE POLICY "app_settings_select" ON app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "app_settings_insert" ON app_settings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "app_settings_update" ON app_settings FOR UPDATE TO authenticated USING (true);
CREATE POLICY "app_settings_delete" ON app_settings FOR DELETE TO authenticated USING (true);
