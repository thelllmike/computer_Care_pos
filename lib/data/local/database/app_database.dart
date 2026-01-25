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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.databaseName));
    return NativeDatabase.createInBackground(file);
  });
}
