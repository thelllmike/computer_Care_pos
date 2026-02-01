-- ============================================================
-- Computer Care POS - Supabase Migration
-- 002_indexes.sql
-- Performance indexes for common queries
-- ============================================================

-- Categories
CREATE INDEX idx_categories_parent_id ON categories(parent_id);
CREATE INDEX idx_categories_is_active ON categories(is_active);

-- Products
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_product_type ON products(product_type);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_name ON products(name);

-- Customers
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_is_active ON customers(is_active);
CREATE INDEX idx_customers_credit_enabled ON customers(credit_enabled);

-- Suppliers
CREATE INDEX idx_suppliers_is_active ON suppliers(is_active);

-- Inventory
CREATE INDEX idx_inventory_product_id ON inventory(product_id);

-- Serial Numbers
CREATE INDEX idx_serial_numbers_product_id ON serial_numbers(product_id);
CREATE INDEX idx_serial_numbers_status ON serial_numbers(status);
CREATE INDEX idx_serial_numbers_customer_id ON serial_numbers(customer_id);
CREATE INDEX idx_serial_numbers_sale_id ON serial_numbers(sale_id);
CREATE INDEX idx_serial_numbers_warranty_end ON serial_numbers(warranty_end_date);

-- Serial Number History
CREATE INDEX idx_serial_number_history_serial_id ON serial_number_history(serial_number_id);
CREATE INDEX idx_serial_number_history_ref ON serial_number_history(reference_type, reference_id);

-- Purchase Orders
CREATE INDEX idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
CREATE INDEX idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX idx_purchase_orders_order_date ON purchase_orders(order_date);

-- Purchase Order Items
CREATE INDEX idx_purchase_order_items_po_id ON purchase_order_items(purchase_order_id);
CREATE INDEX idx_purchase_order_items_product_id ON purchase_order_items(product_id);

-- GRN
CREATE INDEX idx_grn_supplier_id ON grn(supplier_id);
CREATE INDEX idx_grn_purchase_order_id ON grn(purchase_order_id);
CREATE INDEX idx_grn_received_date ON grn(received_date);

-- GRN Items
CREATE INDEX idx_grn_items_grn_id ON grn_items(grn_id);
CREATE INDEX idx_grn_items_product_id ON grn_items(product_id);

-- GRN Serials
CREATE INDEX idx_grn_serials_grn_item_id ON grn_serials(grn_item_id);

-- Sales
CREATE INDEX idx_sales_customer_id ON sales(customer_id);
CREATE INDEX idx_sales_sale_date ON sales(sale_date);
CREATE INDEX idx_sales_status ON sales(status);
CREATE INDEX idx_sales_is_credit ON sales(is_credit);
CREATE INDEX idx_sales_quotation_id ON sales(quotation_id);
CREATE INDEX idx_sales_created_at ON sales(created_at);

-- Sale Items
CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product_id ON sale_items(product_id);

-- Sale Serials
CREATE INDEX idx_sale_serials_sale_item_id ON sale_serials(sale_item_id);
CREATE INDEX idx_sale_serials_serial_number_id ON sale_serials(serial_number_id);

-- Payments
CREATE INDEX idx_payments_sale_id ON payments(sale_id);
CREATE INDEX idx_payments_payment_date ON payments(payment_date);
CREATE INDEX idx_payments_payment_method ON payments(payment_method);

-- Quotations
CREATE INDEX idx_quotations_customer_id ON quotations(customer_id);
CREATE INDEX idx_quotations_status ON quotations(status);
CREATE INDEX idx_quotations_quotation_date ON quotations(quotation_date);
CREATE INDEX idx_quotations_valid_until ON quotations(valid_until);

-- Quotation Items
CREATE INDEX idx_quotation_items_quotation_id ON quotation_items(quotation_id);
CREATE INDEX idx_quotation_items_product_id ON quotation_items(product_id);

-- Credit Transactions
CREATE INDEX idx_credit_transactions_customer_id ON credit_transactions(customer_id);
CREATE INDEX idx_credit_transactions_type ON credit_transactions(transaction_type);
CREATE INDEX idx_credit_transactions_date ON credit_transactions(transaction_date);
CREATE INDEX idx_credit_transactions_ref ON credit_transactions(reference_type, reference_id);

-- Repair Jobs
CREATE INDEX idx_repair_jobs_customer_id ON repair_jobs(customer_id);
CREATE INDEX idx_repair_jobs_status ON repair_jobs(status);
CREATE INDEX idx_repair_jobs_received_date ON repair_jobs(received_date);
CREATE INDEX idx_repair_jobs_assigned_to ON repair_jobs(assigned_to);

-- Repair Parts
CREATE INDEX idx_repair_parts_repair_job_id ON repair_parts(repair_job_id);
CREATE INDEX idx_repair_parts_product_id ON repair_parts(product_id);

-- Repair Status History
CREATE INDEX idx_repair_status_history_job_id ON repair_status_history(repair_job_id);

-- Expenses
CREATE INDEX idx_expenses_category ON expenses(category);
CREATE INDEX idx_expenses_expense_date ON expenses(expense_date);

-- Stock Losses
CREATE INDEX idx_stock_losses_product_id ON stock_losses(product_id);
CREATE INDEX idx_stock_losses_loss_date ON stock_losses(loss_date);
CREATE INDEX idx_stock_losses_loss_type ON stock_losses(loss_type);

-- Warranty Claims
CREATE INDEX idx_warranty_claims_serial_id ON warranty_claims(serial_number_id);
CREATE INDEX idx_warranty_claims_supplier_id ON warranty_claims(supplier_id);
CREATE INDEX idx_warranty_claims_status ON warranty_claims(status);

-- Warranty Claim History
CREATE INDEX idx_warranty_claim_history_claim_id ON warranty_claim_history(warranty_claim_id);

-- Audit Logs
CREATE INDEX idx_audit_logs_table_record ON audit_logs(audit_table_name, record_id);
CREATE INDEX idx_audit_logs_changed_at ON audit_logs(changed_at);

-- Sync Queue
CREATE INDEX idx_sync_queue_table ON sync_queue(queue_table_name);
CREATE INDEX idx_sync_queue_processed ON sync_queue(processed_at);

-- Sync status indexes (for finding unsynced records across tables)
CREATE INDEX idx_users_sync_status ON users(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_categories_sync_status ON categories(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_products_sync_status ON products(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_customers_sync_status ON customers(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_suppliers_sync_status ON suppliers(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_inventory_sync_status ON inventory(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_sales_sync_status ON sales(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_quotations_sync_status ON quotations(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_repair_jobs_sync_status ON repair_jobs(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX idx_expenses_sync_status ON expenses(sync_status) WHERE sync_status != 'SYNCED';
