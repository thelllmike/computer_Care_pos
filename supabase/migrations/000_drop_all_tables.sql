-- ============================================================
-- Computer Care POS - Supabase Migration
-- 000_drop_all_tables.sql
-- WARNING: This will DELETE all existing tables and data!
-- Run this BEFORE 001_create_tables.sql
-- ============================================================

-- Drop views first
DROP VIEW IF EXISTS v_active_repairs CASCADE;
DROP VIEW IF EXISTS v_customer_credits CASCADE;
DROP VIEW IF EXISTS v_product_stock CASCADE;
DROP VIEW IF EXISTS v_daily_sales_summary CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS get_next_sequence(TEXT) CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;

-- Drop tables in reverse dependency order
-- (child tables first, then parent tables)

-- Warranty
DROP TABLE IF EXISTS warranty_claim_history CASCADE;
DROP TABLE IF EXISTS warranty_claims CASCADE;

-- Stock Losses
DROP TABLE IF EXISTS stock_losses CASCADE;

-- Expenses
DROP TABLE IF EXISTS expenses CASCADE;

-- Repairs
DROP TABLE IF EXISTS repair_status_history CASCADE;
DROP TABLE IF EXISTS repair_parts CASCADE;
DROP TABLE IF EXISTS repair_jobs CASCADE;

-- Credits
DROP TABLE IF EXISTS credit_transactions CASCADE;

-- Quotations
DROP TABLE IF EXISTS quotation_items CASCADE;
DROP TABLE IF EXISTS quotations CASCADE;

-- Sales
DROP TABLE IF EXISTS sale_serials CASCADE;
DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS sales CASCADE;

-- Purchasing
DROP TABLE IF EXISTS grn_serials CASCADE;
DROP TABLE IF EXISTS grn_items CASCADE;
DROP TABLE IF EXISTS grn CASCADE;
DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;

-- Inventory
DROP TABLE IF EXISTS serial_number_history CASCADE;
DROP TABLE IF EXISTS serial_numbers CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;

-- Master Data
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- System
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS sync_queue CASCADE;
DROP TABLE IF EXISTS sync_metadata CASCADE;
DROP TABLE IF EXISTS number_sequences CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;
