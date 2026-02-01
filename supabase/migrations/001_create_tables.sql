-- ============================================================
-- Computer Care POS - Supabase Migration
-- 001_create_tables.sql
-- Converts local Drift/SQLite schema to PostgreSQL for Supabase
-- ============================================================

-- ==================== SYSTEM TABLES ====================

CREATE TABLE IF NOT EXISTS app_settings (
  id TEXT PRIMARY KEY,
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  data_type TEXT NOT NULL DEFAULT 'STRING',
  updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS number_sequences (
  id TEXT PRIMARY KEY,
  sequence_type TEXT NOT NULL UNIQUE,
  prefix TEXT NOT NULL,
  current_year INTEGER NOT NULL,
  last_number INTEGER NOT NULL DEFAULT 0,
  format TEXT NOT NULL DEFAULT '{PREFIX}-{YEAR}-{NUMBER:4}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sync_metadata (
  id TEXT PRIMARY KEY,
  sync_table_name TEXT NOT NULL UNIQUE,
  last_sync_at TIMESTAMPTZ,
  pending_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  queue_table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  audit_table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  action TEXT NOT NULL,
  old_data TEXT,
  new_data TEXT,
  changed_by TEXT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== MASTER DATA ====================

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'CASHIER',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  parent_id TEXT REFERENCES categories(id),
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  barcode TEXT,
  name TEXT NOT NULL,
  description TEXT,
  category_id TEXT REFERENCES categories(id),
  product_type TEXT NOT NULL DEFAULT 'ACCESSORY',
  requires_serial BOOLEAN NOT NULL DEFAULT FALSE,
  selling_price DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  weighted_avg_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  warranty_months INTEGER NOT NULL DEFAULT 0,
  reorder_level INTEGER NOT NULL DEFAULT 5,
  brand TEXT,
  model TEXT,
  specifications TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  nic TEXT,
  credit_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  credit_limit DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  credit_balance DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS suppliers (
  id TEXT PRIMARY KEY,
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
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== INVENTORY ====================

CREATE TABLE IF NOT EXISTS inventory (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id),
  quantity_on_hand INTEGER NOT NULL DEFAULT 0,
  total_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  reserved_quantity INTEGER NOT NULL DEFAULT 0,
  last_stock_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS serial_numbers (
  id TEXT PRIMARY KEY,
  serial_number TEXT NOT NULL UNIQUE,
  product_id TEXT NOT NULL REFERENCES products(id),
  status TEXT NOT NULL DEFAULT 'IN_STOCK',
  unit_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  grn_id TEXT,
  grn_item_id TEXT,
  sale_id TEXT,
  customer_id TEXT REFERENCES customers(id),
  warranty_start_date TIMESTAMPTZ,
  warranty_end_date TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS serial_number_history (
  id TEXT PRIMARY KEY,
  serial_number_id TEXT NOT NULL REFERENCES serial_numbers(id),
  from_status TEXT NOT NULL,
  to_status TEXT NOT NULL,
  reference_type TEXT,
  reference_id TEXT,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== PURCHASING ====================

CREATE TABLE IF NOT EXISTS purchase_orders (
  id TEXT PRIMARY KEY,
  order_number TEXT NOT NULL UNIQUE,
  supplier_id TEXT NOT NULL REFERENCES suppliers(id),
  order_date TIMESTAMPTZ NOT NULL,
  expected_date TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'DRAFT',
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
  id TEXT PRIMARY KEY,
  purchase_order_id TEXT NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_cost DOUBLE PRECISION NOT NULL,
  total_cost DOUBLE PRECISION NOT NULL,
  received_quantity INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS grn (
  id TEXT PRIMARY KEY,
  grn_number TEXT NOT NULL UNIQUE,
  purchase_order_id TEXT,
  supplier_id TEXT NOT NULL REFERENCES suppliers(id),
  invoice_number TEXT,
  invoice_date TIMESTAMPTZ,
  received_date TIMESTAMPTZ NOT NULL,
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  notes TEXT,
  received_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS grn_items (
  id TEXT PRIMARY KEY,
  grn_id TEXT NOT NULL REFERENCES grn(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  purchase_order_item_id TEXT,
  quantity INTEGER NOT NULL,
  unit_cost DOUBLE PRECISION NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS grn_serials (
  id TEXT PRIMARY KEY,
  grn_item_id TEXT NOT NULL REFERENCES grn_items(id) ON DELETE CASCADE,
  serial_number_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== SALES ====================

CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  invoice_number TEXT NOT NULL UNIQUE,
  customer_id TEXT REFERENCES customers(id),
  quotation_id TEXT,
  sale_date TIMESTAMPTZ NOT NULL,
  subtotal DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  discount_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  tax_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  paid_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  gross_profit DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  is_credit BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'COMPLETED',
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sale_items (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price DOUBLE PRECISION NOT NULL,
  unit_cost DOUBLE PRECISION NOT NULL,
  discount_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_price DOUBLE PRECISION NOT NULL,
  total_cost DOUBLE PRECISION NOT NULL,
  profit DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sale_serials (
  id TEXT PRIMARY KEY,
  sale_item_id TEXT NOT NULL REFERENCES sale_items(id) ON DELETE CASCADE,
  serial_number_id TEXT NOT NULL,
  serial_number TEXT NOT NULL,
  unit_cost DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS payments (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  payment_method TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  reference_number TEXT,
  payment_date TIMESTAMPTZ NOT NULL,
  notes TEXT,
  received_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== QUOTATIONS ====================

CREATE TABLE IF NOT EXISTS quotations (
  id TEXT PRIMARY KEY,
  quotation_number TEXT NOT NULL UNIQUE,
  customer_id TEXT REFERENCES customers(id),
  quotation_date TIMESTAMPTZ NOT NULL,
  valid_until TIMESTAMPTZ,
  subtotal DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  discount_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  tax_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  status TEXT NOT NULL DEFAULT 'DRAFT',
  converted_sale_id TEXT,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS quotation_items (
  id TEXT PRIMARY KEY,
  quotation_id TEXT NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price DOUBLE PRECISION NOT NULL,
  discount_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_price DOUBLE PRECISION NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== CREDITS ====================

CREATE TABLE IF NOT EXISTS credit_transactions (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES customers(id),
  transaction_type TEXT NOT NULL,
  reference_type TEXT,
  reference_id TEXT,
  amount DOUBLE PRECISION NOT NULL,
  balance_after DOUBLE PRECISION NOT NULL,
  notes TEXT,
  created_by TEXT,
  transaction_date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== REPAIRS ====================

CREATE TABLE IF NOT EXISTS repair_jobs (
  id TEXT PRIMARY KEY,
  job_number TEXT NOT NULL UNIQUE,
  customer_id TEXT REFERENCES customers(id),
  manual_customer_name TEXT,
  manual_customer_phone TEXT,
  serial_number_id TEXT,
  device_type TEXT NOT NULL,
  device_brand TEXT,
  device_model TEXT,
  device_serial TEXT,
  problem_description TEXT NOT NULL,
  diagnosis TEXT,
  estimated_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  actual_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  labor_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  parts_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_cost DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  status TEXT NOT NULL DEFAULT 'RECEIVED',
  is_under_warranty BOOLEAN NOT NULL DEFAULT FALSE,
  warranty_notes TEXT,
  received_date TIMESTAMPTZ NOT NULL,
  promised_date TIMESTAMPTZ,
  completed_date TIMESTAMPTZ,
  delivered_date TIMESTAMPTZ,
  received_by TEXT,
  assigned_to TEXT,
  notes TEXT,
  invoice_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS repair_parts (
  id TEXT PRIMARY KEY,
  repair_job_id TEXT NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  serial_number_id TEXT,
  quantity INTEGER NOT NULL,
  unit_cost DOUBLE PRECISION NOT NULL,
  unit_price DOUBLE PRECISION NOT NULL,
  total_cost DOUBLE PRECISION NOT NULL,
  total_price DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS repair_status_history (
  id TEXT PRIMARY KEY,
  repair_job_id TEXT NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
  from_status TEXT,
  to_status TEXT NOT NULL,
  notes TEXT,
  changed_by TEXT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== EXPENSES ====================

CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  expense_number TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  expense_date TIMESTAMPTZ NOT NULL,
  payment_method TEXT,
  reference_number TEXT,
  vendor TEXT,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== STOCK LOSSES ====================

CREATE TABLE IF NOT EXISTS stock_losses (
  id TEXT PRIMARY KEY,
  loss_number TEXT NOT NULL UNIQUE,
  product_id TEXT NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL,
  serial_number_id TEXT REFERENCES serial_numbers(id),
  loss_type TEXT NOT NULL,
  loss_reason TEXT NOT NULL,
  unit_cost DOUBLE PRECISION NOT NULL,
  total_loss_amount DOUBLE PRECISION NOT NULL,
  loss_date TIMESTAMPTZ NOT NULL,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

-- ==================== WARRANTY ====================

CREATE TABLE IF NOT EXISTS warranty_claims (
  id TEXT PRIMARY KEY,
  claim_number TEXT NOT NULL UNIQUE,
  serial_number_id TEXT NOT NULL REFERENCES serial_numbers(id),
  supplier_id TEXT NOT NULL REFERENCES suppliers(id),
  claim_reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING',
  date_sent_to_supplier TIMESTAMPTZ,
  expected_return_date TIMESTAMPTZ,
  actual_return_date TIMESTAMPTZ,
  supplier_response TEXT,
  resolution_notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS warranty_claim_history (
  id TEXT PRIMARY KEY,
  warranty_claim_id TEXT NOT NULL REFERENCES warranty_claims(id) ON DELETE CASCADE,
  from_status TEXT,
  to_status TEXT NOT NULL,
  notes TEXT,
  changed_by TEXT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'SYNCED',
  local_updated_at TIMESTAMPTZ,
  server_updated_at TIMESTAMPTZ
);
