-- Laptop Shop POS - Supabase PostgreSQL Schema
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE product_type AS ENUM ('LAPTOP', 'ACCESSORY', 'SPARE_PART');
CREATE TYPE serial_status AS ENUM ('IN_STOCK', 'SOLD', 'RETURNED', 'IN_REPAIR', 'DEFECTIVE', 'DISPOSED');
CREATE TYPE user_role AS ENUM ('ADMIN', 'CASHIER', 'TECHNICIAN');
CREATE TYPE payment_method AS ENUM ('CASH', 'CARD', 'BANK_TRANSFER', 'CREDIT', 'CHEQUE');
CREATE TYPE order_status AS ENUM ('DRAFT', 'CONFIRMED', 'PARTIALLY_RECEIVED', 'COMPLETED', 'CANCELLED');
CREATE TYPE quotation_status AS ENUM ('DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CONVERTED');
CREATE TYPE repair_status AS ENUM ('RECEIVED', 'DIAGNOSING', 'WAITING_FOR_PARTS', 'IN_PROGRESS', 'COMPLETED', 'READY_FOR_PICKUP', 'DELIVERED', 'CANCELLED');
CREATE TYPE sync_operation AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- =====================================================
-- USERS TABLE
-- =====================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'CASHIER',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- =====================================================
-- CATEGORIES TABLE (Hierarchical)
-- =====================================================

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_categories_parent ON categories(parent_id);

-- =====================================================
-- PRODUCTS TABLE
-- =====================================================

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    barcode TEXT,
    name TEXT NOT NULL,
    description TEXT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    product_type product_type NOT NULL DEFAULT 'ACCESSORY',
    requires_serial BOOLEAN NOT NULL DEFAULT FALSE,
    selling_price DECIMAL(15, 2) NOT NULL DEFAULT 0,
    weighted_avg_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    warranty_months INTEGER NOT NULL DEFAULT 0,
    reorder_level INTEGER NOT NULL DEFAULT 5,
    brand TEXT,
    model TEXT,
    specifications JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_type ON products(product_type);

-- =====================================================
-- CUSTOMERS TABLE
-- =====================================================

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    nic TEXT,
    credit_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    credit_limit DECIMAL(15, 2) NOT NULL DEFAULT 0,
    credit_balance DECIMAL(15, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_credit ON customers(credit_enabled) WHERE credit_enabled = TRUE;

-- =====================================================
-- SUPPLIERS TABLE
-- =====================================================

CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    tax_id TEXT,
    payment_term_days INTEGER NOT NULL DEFAULT 30,
    notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- =====================================================
-- INVENTORY TABLE
-- =====================================================

CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity_on_hand INTEGER NOT NULL DEFAULT 0,
    total_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    reserved_quantity INTEGER NOT NULL DEFAULT 0,
    last_stock_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    UNIQUE(product_id)
);

CREATE INDEX idx_inventory_low_stock ON inventory(quantity_on_hand) WHERE quantity_on_hand <= 5;

-- =====================================================
-- SERIAL NUMBERS TABLE
-- =====================================================

CREATE TABLE serial_numbers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    serial_number TEXT NOT NULL UNIQUE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    status serial_status NOT NULL DEFAULT 'IN_STOCK',
    unit_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    grn_id UUID,
    grn_item_id UUID,
    sale_id UUID,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    warranty_start_date DATE,
    warranty_end_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_serial_numbers_product ON serial_numbers(product_id);
CREATE INDEX idx_serial_numbers_status ON serial_numbers(status);
CREATE INDEX idx_serial_numbers_customer ON serial_numbers(customer_id);

-- =====================================================
-- SERIAL NUMBER HISTORY TABLE (Audit Trail)
-- =====================================================

CREATE TABLE serial_number_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    serial_number_id UUID NOT NULL REFERENCES serial_numbers(id) ON DELETE CASCADE,
    from_status serial_status,
    to_status serial_status NOT NULL,
    reference_type TEXT,
    reference_id UUID,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_serial_history_serial ON serial_number_history(serial_number_id);

-- =====================================================
-- PURCHASE ORDERS
-- =====================================================

CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number TEXT NOT NULL UNIQUE,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    order_date DATE NOT NULL,
    expected_date DATE,
    status order_status NOT NULL DEFAULT 'DRAFT',
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_po_supplier ON purchase_orders(supplier_id);
CREATE INDEX idx_po_status ON purchase_orders(status);

CREATE TABLE purchase_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    unit_cost DECIMAL(15, 2) NOT NULL,
    total_cost DECIMAL(15, 2) NOT NULL,
    received_quantity INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_poi_po ON purchase_order_items(purchase_order_id);

-- =====================================================
-- GOODS RECEIVED NOTES (GRN)
-- =====================================================

CREATE TABLE goods_received_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_number TEXT NOT NULL UNIQUE,
    purchase_order_id UUID REFERENCES purchase_orders(id) ON DELETE SET NULL,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    received_date DATE NOT NULL,
    supplier_invoice_no TEXT,
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    received_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_grn_supplier ON goods_received_notes(supplier_id);
CREATE INDEX idx_grn_po ON goods_received_notes(purchase_order_id);

CREATE TABLE grn_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_id UUID NOT NULL REFERENCES goods_received_notes(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    purchase_order_item_id UUID REFERENCES purchase_order_items(id),
    quantity INTEGER NOT NULL,
    unit_cost DECIMAL(15, 2) NOT NULL,
    total_cost DECIMAL(15, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_grn_items_grn ON grn_items(grn_id);

CREATE TABLE grn_serials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_item_id UUID NOT NULL REFERENCES grn_items(id) ON DELETE CASCADE,
    serial_number_id UUID NOT NULL REFERENCES serial_numbers(id) ON DELETE RESTRICT,
    serial_number TEXT NOT NULL,
    unit_cost DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_grn_serials_item ON grn_serials(grn_item_id);

-- =====================================================
-- QUOTATIONS
-- =====================================================

CREATE TABLE quotations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quotation_number TEXT NOT NULL UNIQUE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    quotation_date DATE NOT NULL,
    valid_until DATE,
    subtotal DECIMAL(15, 2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    status quotation_status NOT NULL DEFAULT 'DRAFT',
    converted_sale_id UUID,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_quotations_customer ON quotations(customer_id);
CREATE INDEX idx_quotations_status ON quotations(status);

CREATE TABLE quotation_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quotation_id UUID NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15, 2) NOT NULL,
    discount_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    total_price DECIMAL(15, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_qi_quotation ON quotation_items(quotation_id);

-- =====================================================
-- SALES
-- =====================================================

CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number TEXT NOT NULL UNIQUE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    quotation_id UUID REFERENCES quotations(id) ON DELETE SET NULL,
    sale_date TIMESTAMPTZ NOT NULL,
    subtotal DECIMAL(15, 2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    total_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    gross_profit DECIMAL(15, 2) NOT NULL DEFAULT 0,
    is_credit BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'COMPLETED',
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sales_credit ON sales(is_credit) WHERE is_credit = TRUE;

CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15, 2) NOT NULL,
    unit_cost DECIMAL(15, 2) NOT NULL,
    discount_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    total_price DECIMAL(15, 2) NOT NULL,
    total_cost DECIMAL(15, 2) NOT NULL,
    profit DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_si_sale ON sale_items(sale_id);

CREATE TABLE sale_serials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_item_id UUID NOT NULL REFERENCES sale_items(id) ON DELETE CASCADE,
    serial_number_id UUID NOT NULL REFERENCES serial_numbers(id) ON DELETE RESTRICT,
    serial_number TEXT NOT NULL,
    unit_cost DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sale_serials_item ON sale_serials(sale_item_id);

-- =====================================================
-- PAYMENTS
-- =====================================================

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    payment_method payment_method NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    reference_number TEXT,
    payment_date TIMESTAMPTZ NOT NULL,
    notes TEXT,
    received_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_payments_sale ON payments(sale_id);

-- =====================================================
-- CREDIT TRANSACTIONS (Receivables Ledger)
-- =====================================================

CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    transaction_type TEXT NOT NULL, -- SALE, PAYMENT, ADJUSTMENT
    reference_type TEXT,
    reference_id UUID,
    amount DECIMAL(15, 2) NOT NULL,
    balance_after DECIMAL(15, 2) NOT NULL,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    transaction_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_credit_tx_customer ON credit_transactions(customer_id);

-- =====================================================
-- REPAIR JOBS
-- =====================================================

CREATE TABLE repair_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_number TEXT NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    serial_number_id UUID REFERENCES serial_numbers(id) ON DELETE SET NULL,
    device_type TEXT NOT NULL,
    device_brand TEXT,
    device_model TEXT,
    device_serial TEXT,
    problem_description TEXT NOT NULL,
    diagnosis TEXT,
    estimated_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    actual_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    labor_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    parts_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    total_cost DECIMAL(15, 2) NOT NULL DEFAULT 0,
    status repair_status NOT NULL DEFAULT 'RECEIVED',
    is_under_warranty BOOLEAN NOT NULL DEFAULT FALSE,
    warranty_notes TEXT,
    received_date TIMESTAMPTZ NOT NULL,
    promised_date TIMESTAMPTZ,
    completed_date TIMESTAMPTZ,
    delivered_date TIMESTAMPTZ,
    received_by UUID REFERENCES users(id),
    assigned_to UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_repair_customer ON repair_jobs(customer_id);
CREATE INDEX idx_repair_status ON repair_jobs(status);
CREATE INDEX idx_repair_serial ON repair_jobs(serial_number_id);

CREATE TABLE repair_parts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    repair_job_id UUID NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    serial_number_id UUID REFERENCES serial_numbers(id) ON DELETE SET NULL,
    quantity INTEGER NOT NULL,
    unit_cost DECIMAL(15, 2) NOT NULL,
    unit_price DECIMAL(15, 2) NOT NULL,
    total_cost DECIMAL(15, 2) NOT NULL,
    total_price DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE INDEX idx_repair_parts_job ON repair_parts(repair_job_id);

CREATE TABLE repair_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    repair_job_id UUID NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
    from_status repair_status,
    to_status repair_status NOT NULL,
    notes TEXT,
    changed_by UUID REFERENCES users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_repair_history_job ON repair_status_history(repair_job_id);

-- =====================================================
-- AUDIT LOGS
-- =====================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action TEXT NOT NULL, -- INSERT, UPDATE, DELETE
    old_data JSONB,
    new_data JSONB,
    changed_by UUID REFERENCES users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_table ON audit_logs(table_name);
CREATE INDEX idx_audit_record ON audit_logs(record_id);
CREATE INDEX idx_audit_date ON audit_logs(changed_at);

-- =====================================================
-- NUMBER SEQUENCES
-- =====================================================

CREATE TABLE number_sequences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sequence_type TEXT NOT NULL UNIQUE,
    prefix TEXT NOT NULL,
    current_year INTEGER NOT NULL,
    last_number INTEGER NOT NULL DEFAULT 0,
    format TEXT NOT NULL DEFAULT '{PREFIX}-{YEAR}-{NUMBER:4}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Insert initial sequences
INSERT INTO number_sequences (sequence_type, prefix, current_year) VALUES
    ('INVOICE', 'INV', EXTRACT(YEAR FROM NOW())),
    ('QUOTATION', 'QTN', EXTRACT(YEAR FROM NOW())),
    ('PURCHASE_ORDER', 'PO', EXTRACT(YEAR FROM NOW())),
    ('GRN', 'GRN', EXTRACT(YEAR FROM NOW())),
    ('REPAIR_JOB', 'RJ', EXTRACT(YEAR FROM NOW())),
    ('CUSTOMER', 'C', EXTRACT(YEAR FROM NOW())),
    ('SUPPLIER', 'S', EXTRACT(YEAR FROM NOW())),
    ('PRODUCT', 'P', EXTRACT(YEAR FROM NOW()));

-- =====================================================
-- SYNC METADATA (For offline sync tracking)
-- =====================================================

CREATE TABLE sync_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL UNIQUE,
    last_sync_at TIMESTAMPTZ,
    pending_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

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
ALTER TABLE goods_received_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn_serials ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_serials ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE repair_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE number_sequences ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users (allow all for now, customize as needed)
CREATE POLICY "Allow authenticated access" ON users FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON categories FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON products FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON customers FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON suppliers FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON inventory FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON serial_numbers FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON serial_number_history FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON purchase_orders FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON purchase_order_items FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON goods_received_notes FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON grn_items FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON grn_serials FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON quotations FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON quotation_items FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON sales FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON sale_items FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON sale_serials FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON payments FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON credit_transactions FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON repair_jobs FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON repair_parts FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON repair_status_history FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON audit_logs FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON number_sequences FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated access" ON sync_metadata FOR ALL TO authenticated USING (true);

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Function to get next sequence number
CREATE OR REPLACE FUNCTION get_next_sequence_number(p_sequence_type TEXT)
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT;
    v_current_year INTEGER;
    v_last_number INTEGER;
    v_new_number INTEGER;
    v_result TEXT;
BEGIN
    -- Get current sequence
    SELECT prefix, current_year, last_number
    INTO v_prefix, v_current_year, v_last_number
    FROM number_sequences
    WHERE sequence_type = p_sequence_type
    FOR UPDATE;

    -- Check if year changed
    IF v_current_year != EXTRACT(YEAR FROM NOW()) THEN
        v_current_year := EXTRACT(YEAR FROM NOW());
        v_new_number := 1;
    ELSE
        v_new_number := v_last_number + 1;
    END IF;

    -- Update sequence
    UPDATE number_sequences
    SET current_year = v_current_year,
        last_number = v_new_number,
        updated_at = NOW()
    WHERE sequence_type = p_sequence_type;

    -- Format result (e.g., INV-2024-0001)
    v_result := v_prefix || '-' || v_current_year || '-' || LPAD(v_new_number::TEXT, 4, '0');

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate weighted average cost
CREATE OR REPLACE FUNCTION calculate_wac(
    p_product_id UUID,
    p_new_quantity INTEGER,
    p_new_unit_cost DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
    v_existing_qty INTEGER;
    v_existing_total_cost DECIMAL;
    v_new_wac DECIMAL;
BEGIN
    SELECT quantity_on_hand, total_cost
    INTO v_existing_qty, v_existing_total_cost
    FROM inventory
    WHERE product_id = p_product_id;

    IF v_existing_qty IS NULL THEN
        v_existing_qty := 0;
        v_existing_total_cost := 0;
    END IF;

    -- WAC = (Existing Value + New Purchase Value) / (Existing Qty + New Qty)
    v_new_wac := (v_existing_total_cost + (p_new_quantity * p_new_unit_cost)) /
                 NULLIF(v_existing_qty + p_new_quantity, 0);

    RETURN COALESCE(v_new_wac, p_new_unit_cost);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_inventory_updated_at BEFORE UPDATE ON inventory FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_serial_numbers_updated_at BEFORE UPDATE ON serial_numbers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_purchase_orders_updated_at BEFORE UPDATE ON purchase_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_grn_updated_at BEFORE UPDATE ON goods_received_notes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_quotations_updated_at BEFORE UPDATE ON quotations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_repair_jobs_updated_at BEFORE UPDATE ON repair_jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to create user record when auth user is created
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (auth_id, email, name, role)
    VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
            COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'CASHIER'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
