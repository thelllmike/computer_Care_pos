import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_constants.dart';
import '../tables/tables.dart';
import '../daos/category_dao.dart';
import '../daos/credit_dao.dart';
import '../daos/product_dao.dart';
import '../daos/customer_dao.dart';
import '../daos/supplier_dao.dart';
import '../daos/inventory_dao.dart';
import '../daos/purchase_order_dao.dart';
import '../daos/grn_dao.dart';
import '../daos/repair_dao.dart';
import '../daos/sales_dao.dart';
import '../daos/quotation_dao.dart';
import '../daos/expense_dao.dart';
import '../daos/stock_loss_dao.dart';
import '../daos/warranty_claim_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Master data
    Users,
    Categories,
    Products,
    Customers,
    Suppliers,
    // Inventory
    Inventory,
    SerialNumbers,
    SerialNumberHistory,
    // Purchasing
    PurchaseOrders,
    PurchaseOrderItems,
    Grn,
    GrnItems,
    GrnSerials,
    // Sales
    Sales,
    SaleItems,
    SaleSerials,
    Quotations,
    QuotationItems,
    Payments,
    CreditTransactions,
    // Repairs
    RepairJobs,
    RepairParts,
    RepairStatusHistory,
    // Expenses
    Expenses,
    // Stock Losses
    StockLosses,
    // Warranty
    WarrantyClaims,
    WarrantyClaimHistory,
    // System
    AuditLogs,
    NumberSequences,
    SyncMetadata,
    SyncQueue,
    AppSettings,
  ],
  daos: [
    CategoryDao,
    CreditDao,
    ProductDao,
    CustomerDao,
    SupplierDao,
    InventoryDao,
    PurchaseOrderDao,
    GrnDao,
    RepairDao,
    SalesDao,
    QuotationDao,
    ExpenseDao,
    StockLossDao,
    WarrantyClaimDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor e) : super(e);

  /// Lookup indexes for the columns the app filters and joins on most.
  /// Indexes only speed up reads; they never change stored data.
  static const _indexes = <String, String>{
    'idx_sales_sale_date': 'sales(sale_date)',
    'idx_sales_customer': 'sales(customer_id)',
    'idx_sales_sync': 'sales(sync_status)',
    'idx_sale_items_sale': 'sale_items(sale_id)',
    'idx_sale_items_product': 'sale_items(product_id)',
    'idx_sale_items_sync': 'sale_items(sync_status)',
    'idx_sale_serials_item': 'sale_serials(sale_item_id)',
    'idx_payments_sale': 'payments(sale_id)',
    'idx_payments_sync': 'payments(sync_status)',
    'idx_credit_tx_customer': 'credit_transactions(customer_id)',
    'idx_inventory_product': 'inventory(product_id)',
    'idx_inventory_sync': 'inventory(sync_status)',
    'idx_products_category': 'products(category_id)',
    'idx_products_sync': 'products(sync_status)',
    'idx_serials_product_status': 'serial_numbers(product_id, status)',
    'idx_serials_sale': 'serial_numbers(sale_id)',
    'idx_customers_sync': 'customers(sync_status)',
    'idx_grn_items_grn': 'grn_items(grn_id)',
    'idx_po_items_po': 'purchase_order_items(purchase_order_id)',
    'idx_quotation_items_quotation': 'quotation_items(quotation_id)',
    'idx_repair_jobs_customer': 'repair_jobs(customer_id)',
    'idx_repair_jobs_status': 'repair_jobs(status)',
    'idx_repair_parts_job': 'repair_parts(repair_job_id)',
    'idx_sync_queue_processed': 'sync_queue(processed_at)',
  };

  Future<void> _createIndexes() async {
    for (final e in _indexes.entries) {
      await customStatement('CREATE INDEX IF NOT EXISTS ${e.key} ON ${e.value}');
    }
  }

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createIndexes();
        await _seedInitialData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2
        if (from < 2) {
          // Create expenses table
          await m.createTable(expenses);

          // Add manual customer columns to repair_jobs
          await customStatement(
            'ALTER TABLE repair_jobs ADD COLUMN manual_customer_name TEXT',
          );
          await customStatement(
            'ALTER TABLE repair_jobs ADD COLUMN manual_customer_phone TEXT',
          );

          // Add expense sequence
          await into(numberSequences).insert(
            NumberSequencesCompanion.insert(
              id: 'seq_expense',
              sequenceType: 'EXPENSE',
              prefix: 'EXP',
              currentYear: DateTime.now().year,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }

        // Migration from version 2 to 3
        if (from < 3) {
          final year = DateTime.now().year;

          // Create stock losses table
          await m.createTable(stockLosses);

          // Create warranty claims tables
          await m.createTable(warrantyClaims);
          await m.createTable(warrantyClaimHistory);

          // Add stock loss sequence
          await into(numberSequences).insert(
            NumberSequencesCompanion.insert(
              id: 'seq_stock_loss',
              sequenceType: 'STOCK_LOSS',
              prefix: 'LOSS',
              currentYear: year,
            ),
            mode: InsertMode.insertOrIgnore,
          );

          // Add warranty claim sequence
          await into(numberSequences).insert(
            NumberSequencesCompanion.insert(
              id: 'seq_warranty_claim',
              sequenceType: 'WARRANTY_CLAIM',
              prefix: 'WC',
              currentYear: year,
            ),
            mode: InsertMode.insertOrIgnore,
          );

          // Add sync metadata for new tables
          await batch((batch) {
            batch.insertAll(
              syncMetadata,
              [
                SyncMetadataCompanion.insert(
                  id: 'sync_stock_losses',
                  syncTableName: 'stock_losses',
                ),
                SyncMetadataCompanion.insert(
                  id: 'sync_warranty_claims',
                  syncTableName: 'warranty_claims',
                ),
                SyncMetadataCompanion.insert(
                  id: 'sync_warranty_claim_history',
                  syncTableName: 'warranty_claim_history',
                ),
              ],
            );
          });
        }

        // Migration from version 3 to 4
        if (from < 4) {
          // Add invoice_id column to repair_jobs to track generated invoices
          await customStatement(
            'ALTER TABLE repair_jobs ADD COLUMN invoice_id TEXT',
          );
        }

        // Migration from version 4 to 5: wholesale price per product
        if (from < 5) {
          await m.addColumn(products, products.wholesalePrice);
        }

        if (from < 6) {
          await _createIndexes();
        }
      },
    );
  }

  Future<void> _seedInitialData() async {
    // Seed number sequences
    final year = DateTime.now().year;
    await batch((batch) {
      batch.insertAll(numberSequences, [
        NumberSequencesCompanion.insert(
          id: 'seq_invoice',
          sequenceType: 'INVOICE',
          prefix: AppConstants.invoicePrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_quotation',
          sequenceType: 'QUOTATION',
          prefix: AppConstants.quotationPrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_po',
          sequenceType: 'PURCHASE_ORDER',
          prefix: AppConstants.purchaseOrderPrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_grn',
          sequenceType: 'GRN',
          prefix: AppConstants.grnPrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_repair',
          sequenceType: 'REPAIR_JOB',
          prefix: AppConstants.repairJobPrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_customer',
          sequenceType: 'CUSTOMER',
          prefix: AppConstants.customerPrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_supplier',
          sequenceType: 'SUPPLIER',
          prefix: AppConstants.supplierPrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_product',
          sequenceType: 'PRODUCT',
          prefix: AppConstants.productPrefix,
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_expense',
          sequenceType: 'EXPENSE',
          prefix: 'EXP',
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_stock_loss',
          sequenceType: 'STOCK_LOSS',
          prefix: 'LOSS',
          currentYear: year,
        ),
        NumberSequencesCompanion.insert(
          id: 'seq_warranty_claim',
          sequenceType: 'WARRANTY_CLAIM',
          prefix: 'WC',
          currentYear: year,
        ),
      ]);

      // Seed sync metadata for each table
      final tables = [
        'users', 'categories', 'products', 'customers', 'suppliers',
        'inventory', 'serial_numbers', 'serial_number_history',
        'purchase_orders', 'purchase_order_items',
        'grn', 'grn_items', 'grn_serials',
        'sales', 'sale_items', 'sale_serials',
        'quotations', 'quotation_items',
        'payments', 'credit_transactions',
        'repair_jobs', 'repair_parts', 'repair_status_history',
        'expenses',
        'stock_losses', 'warranty_claims', 'warranty_claim_history',
        'audit_logs', 'number_sequences',
      ];

      batch.insertAll(
        syncMetadata,
        tables.map((table) => SyncMetadataCompanion.insert(
          id: 'sync_$table',
          syncTableName: table,
        )).toList(),
      );
    });
  }

  // Helper method to generate next number in sequence
  Future<String> getNextSequenceNumber(String sequenceType) async {
    return transaction(() async {
      final seq = await (select(numberSequences)
        ..where((t) => t.sequenceType.equals(sequenceType)))
        .getSingle();

      final currentYear = DateTime.now().year;
      int nextNumber;

      if (seq.currentYear != currentYear) {
        // Reset sequence for new year
        nextNumber = 1;
        await (update(numberSequences)
          ..where((t) => t.sequenceType.equals(sequenceType)))
          .write(NumberSequencesCompanion(
            currentYear: Value(currentYear),
            lastNumber: const Value(1),
            updatedAt: Value(DateTime.now()),
          ));
      } else {
        nextNumber = seq.lastNumber + 1;
        await (update(numberSequences)
          ..where((t) => t.sequenceType.equals(sequenceType)))
          .write(NumberSequencesCompanion(
            lastNumber: Value(nextNumber),
            updatedAt: Value(DateTime.now()),
          ));
      }

      // Format: PREFIX-YEAR-NUMBER (e.g., INV-2024-0001)
      return '${seq.prefix}-$currentYear-${nextNumber.toString().padLeft(4, '0')}';
    });
  }

  /// Syncs the local sequence number with the remote max value
  /// to prevent generating duplicate numbers after multi-device usage
  Future<void> syncSequenceNumber(
      String sequenceType, int year, int maxNumber) async {
    await transaction(() async {
      final seq = await (select(numberSequences)
            ..where((t) => t.sequenceType.equals(sequenceType)))
          .getSingle();

      // Only update if the remote number is higher than local
      if (seq.currentYear == year && seq.lastNumber < maxNumber) {
        await (update(numberSequences)
              ..where((t) => t.sequenceType.equals(sequenceType)))
            .write(NumberSequencesCompanion(
          lastNumber: Value(maxNumber),
          updatedAt: Value(DateTime.now()),
        ));
      } else if (seq.currentYear < year) {
        // Remote is in a newer year, update both
        await (update(numberSequences)
              ..where((t) => t.sequenceType.equals(sequenceType)))
            .write(NumberSequencesCompanion(
          currentYear: Value(year),
          lastNumber: Value(maxNumber),
          updatedAt: Value(DateTime.now()),
        ));
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.databaseName));
    return NativeDatabase.createInBackground(file);
  });
}
