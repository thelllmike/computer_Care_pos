class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Laptop Shop POS';
  static const String appVersion = '1.0.0';

  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Database
  static const String databaseName = 'laptop_shop_pos.db';

  // Sync Settings
  static const int syncIntervalMinutes = 5;
  static const int maxRetryAttempts = 3;

  // Pagination
  static const int defaultPageSize = 50;

  // Invoice Formats
  static const String invoicePrefix = 'INV';
  static const String quotationPrefix = 'QTN';
  static const String purchaseOrderPrefix = 'PO';
  static const String grnPrefix = 'GRN';
  static const String repairJobPrefix = 'RJ';
  static const String customerPrefix = 'C';
  static const String supplierPrefix = 'S';
  static const String productPrefix = 'P';

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'dd/MM/yyyy';
  static const String displayDateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Receipt Settings
  static const int thermalReceiptWidth = 80; // mm
  static const int receiptMaxChars = 48; // characters per line for 80mm

  // Credit Aging Buckets (days)
  static const List<int> agingBuckets = [30, 60, 90];

  // Default Values
  static const int defaultWarrantyMonths = 12;
  static const double defaultTaxRate = 0.0;
}
