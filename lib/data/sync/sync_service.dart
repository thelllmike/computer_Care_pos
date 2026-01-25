import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../local/database/app_database.dart';

enum SyncDirection { push, pull, both }

class SyncResult {
  final bool success;
  final int pushedCount;
  final int pulledCount;
  final List<String> errors;

  const SyncResult({
    required this.success,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.errors = const [],
  });
}

class SyncService {
  final AppDatabase _database;
  final SupabaseClient _supabaseClient;
  final Connectivity _connectivity;

  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService({
    required AppDatabase database,
    required SupabaseClient supabaseClient,
    Connectivity? connectivity,
  })  : _database = database,
        _supabaseClient = supabaseClient,
        _connectivity = connectivity ?? Connectivity();

  /// Starts the periodic sync timer
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: AppConstants.syncIntervalMinutes),
      (_) => sync(),
    );
  }

  /// Stops the periodic sync timer
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Checks if the device is online
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Main sync method that handles both push and pull
  Future<SyncResult> sync({SyncDirection direction = SyncDirection.both}) async {
    if (_isSyncing) {
      return const SyncResult(
        success: false,
        errors: ['Sync already in progress'],
      );
    }

    if (!await isOnline()) {
      return const SyncResult(
        success: false,
        errors: ['No internet connection'],
      );
    }

    _isSyncing = true;
    final errors = <String>[];
    var pushedCount = 0;
    var pulledCount = 0;

    try {
      // Push local changes first (for transactions, local wins)
      if (direction == SyncDirection.push || direction == SyncDirection.both) {
        final pushResult = await _pushChanges();
        pushedCount = pushResult.count;
        errors.addAll(pushResult.errors);
      }

      // Pull remote changes (for master data, server wins)
      if (direction == SyncDirection.pull || direction == SyncDirection.both) {
        final pullResult = await _pullChanges();
        pulledCount = pullResult.count;
        errors.addAll(pullResult.errors);
      }

      return SyncResult(
        success: errors.isEmpty,
        pushedCount: pushedCount,
        pulledCount: pulledCount,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        errors: ['Sync failed: $e'],
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Pushes local pending changes to Supabase
  Future<({int count, List<String> errors})> _pushChanges() async {
    final errors = <String>[];
    var count = 0;

    // Push pending records from each table based on syncStatus
    count += await _pushPendingTable('categories', _database.categories, errors);
    count += await _pushPendingTable('products', _database.products, errors);
    count += await _pushPendingTable('customers', _database.customers, errors);
    count += await _pushPendingTable('suppliers', _database.suppliers, errors);
    count += await _pushPendingTable('inventory', _database.inventory, errors);
    count += await _pushPendingTable('sales', _database.sales, errors);
    count += await _pushPendingTable('repair_jobs', _database.repairJobs, errors);

    return (count: count, errors: errors);
  }

  /// Push pending records from a specific table
  Future<int> _pushPendingTable<T extends Table, D>(
    String tableName,
    TableInfo<T, D> table,
    List<String> errors,
  ) async {
    var count = 0;

    try {
      // Get records with PENDING sync status
      final query = _database.select(table);
      final records = await query.get();

      for (final record in records) {
        final recordMap = (record as dynamic);

        // Check if syncStatus is PENDING
        if (recordMap.syncStatus != 'PENDING') continue;

        try {
          // Convert to JSON for Supabase
          final data = _recordToJson(tableName, record);
          if (data == null) continue;

          // Upsert to Supabase
          await _supabaseClient
              .from(tableName)
              .upsert(data, onConflict: 'id');

          // Mark as synced
          await _markAsSynced(tableName, recordMap.id as String);
          count++;
        } catch (e) {
          errors.add('Failed to push $tableName/${recordMap.id}: $e');
        }
      }
    } catch (e) {
      errors.add('Failed to query $tableName: $e');
    }

    return count;
  }

  /// Convert a record to JSON for Supabase
  Map<String, dynamic>? _recordToJson(String tableName, dynamic record) {
    try {
      switch (tableName) {
        case 'categories':
          return {
            'id': record.id,
            'code': record.code,
            'name': record.name,
            'description': record.description,
            'parent_id': record.parentId,
            'sort_order': record.sortOrder,
            'is_active': record.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          };
        case 'products':
          return {
            'id': record.id,
            'code': record.code,
            'name': record.name,
            'barcode': record.barcode,
            'description': record.description,
            'category_id': record.categoryId,
            'product_type': record.productType,
            'requires_serial': record.requiresSerial,
            'selling_price': record.sellingPrice,
            'weighted_avg_cost': record.weightedAvgCost,
            'warranty_months': record.warrantyMonths,
            'reorder_level': record.reorderLevel,
            'brand': record.brand,
            'model': record.model,
            'is_active': record.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          };
        case 'customers':
          return {
            'id': record.id,
            'code': record.code,
            'name': record.name,
            'email': record.email,
            'phone': record.phone,
            'address': record.address,
            'nic': record.nic,
            'credit_enabled': record.creditEnabled,
            'credit_limit': record.creditLimit,
            'credit_balance': record.creditBalance,
            'notes': record.notes,
            'is_active': record.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          };
        case 'suppliers':
          return {
            'id': record.id,
            'code': record.code,
            'name': record.name,
            'contact_person': record.contactPerson,
            'email': record.email,
            'phone': record.phone,
            'address': record.address,
            'tax_id': record.taxId,
            'payment_term_days': record.paymentTermDays,
            'notes': record.notes,
            'is_active': record.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          };
        case 'inventory':
          return {
            'id': record.id,
            'product_id': record.productId,
            'quantity_on_hand': record.quantityOnHand,
            'total_cost': record.totalCost,
            'reserved_quantity': record.reservedQuantity,
            'last_stock_date': record.lastStockDate?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        case 'sales':
          return {
            'id': record.id,
            'invoice_number': record.invoiceNumber,
            'customer_id': record.customerId,
            'sale_date': record.saleDate.toIso8601String(),
            'subtotal': record.subtotal,
            'discount_amount': record.discountAmount,
            'tax_amount': record.taxAmount,
            'total_amount': record.totalAmount,
            'paid_amount': record.paidAmount,
            'total_cost': record.totalCost,
            'gross_profit': record.grossProfit,
            'is_credit': record.isCredit,
            'status': record.status,
            'notes': record.notes,
            'created_by': record.createdBy,
            'updated_at': DateTime.now().toIso8601String(),
          };
        case 'repair_jobs':
          return {
            'id': record.id,
            'job_number': record.jobNumber,
            'customer_id': record.customerId,
            'device_type': record.deviceType,
            'device_brand': record.deviceBrand,
            'device_model': record.deviceModel,
            'device_serial': record.deviceSerial,
            'problem_description': record.problemDescription,
            'diagnosis': record.diagnosis,
            'estimated_cost': record.estimatedCost,
            'actual_cost': record.actualCost,
            'labor_cost': record.laborCost,
            'parts_cost': record.partsCost,
            'total_cost': record.totalCost,
            'status': record.status,
            'received_date': record.receivedDate.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Mark a record as synced
  Future<void> _markAsSynced(String tableName, String id) async {
    final now = DateTime.now();

    switch (tableName) {
      case 'categories':
        await (_database.update(_database.categories)
              ..where((t) => t.id.equals(id)))
            .write(CategoriesCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'products':
        await (_database.update(_database.products)
              ..where((t) => t.id.equals(id)))
            .write(ProductsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'customers':
        await (_database.update(_database.customers)
              ..where((t) => t.id.equals(id)))
            .write(CustomersCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'suppliers':
        await (_database.update(_database.suppliers)
              ..where((t) => t.id.equals(id)))
            .write(SuppliersCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'inventory':
        await (_database.update(_database.inventory)
              ..where((t) => t.id.equals(id)))
            .write(InventoryCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'sales':
        await (_database.update(_database.sales)
              ..where((t) => t.id.equals(id)))
            .write(SalesCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'repair_jobs':
        await (_database.update(_database.repairJobs)
              ..where((t) => t.id.equals(id)))
            .write(RepairJobsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
    }
  }

  /// Pulls changes from Supabase to local database
  Future<({int count, List<String> errors})> _pullChanges() async {
    final errors = <String>[];
    var count = 0;

    // Tables to sync (master data first, then transactions)
    final tables = [
      'categories',
      'products',
      'customers',
      'suppliers',
      'inventory',
      'serial_numbers',
    ];

    for (final table in tables) {
      try {
        // Get last sync time for this table
        final syncMeta = await (_database.select(_database.syncMetadata)
              ..where((t) => t.syncTableName.equals(table)))
            .getSingleOrNull();

        final lastSync = syncMeta?.lastSyncAt;

        // Fetch records updated since last sync
        var query = _supabaseClient.from(table).select();
        if (lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
        }

        final records = await query;

        // Upsert records to local database
        for (final record in records) {
          await _upsertRecord(table, record);
          count++;
        }

        // Update sync metadata
        await (_database.update(_database.syncMetadata)
              ..where((t) => t.syncTableName.equals(table)))
            .write(SyncMetadataCompanion(
          lastSyncAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        errors.add('Failed to pull $table: $e');
      }
    }

    return (count: count, errors: errors);
  }

  /// Upserts a record to the local database based on table name
  Future<void> _upsertRecord(String table, Map<String, dynamic> record) async {
    final updatedAt = record['updated_at'] != null
        ? DateTime.tryParse(record['updated_at'] as String)
        : null;

    switch (table) {
      case 'categories':
        await _database.into(_database.categories).insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: record['id'] as String,
                code: record['code'] as String,
                name: record['name'] as String,
                description: Value(record['description'] as String?),
                parentId: Value(record['parent_id'] as String?),
                sortOrder: Value(record['sort_order'] as int? ?? 0),
                isActive: Value(record['is_active'] as bool? ?? true),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'products':
        await _database.into(_database.products).insertOnConflictUpdate(
              ProductsCompanion.insert(
                id: record['id'] as String,
                code: record['code'] as String,
                name: record['name'] as String,
                barcode: Value(record['barcode'] as String?),
                description: Value(record['description'] as String?),
                categoryId: Value(record['category_id'] as String?),
                productType: Value(record['product_type'] as String? ?? 'ACCESSORY'),
                requiresSerial: Value(record['requires_serial'] as bool? ?? false),
                sellingPrice: Value((record['selling_price'] as num?)?.toDouble() ?? 0),
                weightedAvgCost: Value((record['weighted_avg_cost'] as num?)?.toDouble() ?? 0),
                warrantyMonths: Value(record['warranty_months'] as int? ?? 0),
                reorderLevel: Value(record['reorder_level'] as int? ?? 5),
                brand: Value(record['brand'] as String?),
                model: Value(record['model'] as String?),
                isActive: Value(record['is_active'] as bool? ?? true),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'customers':
        await _database.into(_database.customers).insertOnConflictUpdate(
              CustomersCompanion.insert(
                id: record['id'] as String,
                code: record['code'] as String,
                name: record['name'] as String,
                email: Value(record['email'] as String?),
                phone: Value(record['phone'] as String?),
                address: Value(record['address'] as String?),
                nic: Value(record['nic'] as String?),
                creditEnabled: Value(record['credit_enabled'] as bool? ?? false),
                creditLimit: Value((record['credit_limit'] as num?)?.toDouble() ?? 0),
                creditBalance: Value((record['credit_balance'] as num?)?.toDouble() ?? 0),
                notes: Value(record['notes'] as String?),
                isActive: Value(record['is_active'] as bool? ?? true),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'suppliers':
        await _database.into(_database.suppliers).insertOnConflictUpdate(
              SuppliersCompanion.insert(
                id: record['id'] as String,
                code: record['code'] as String,
                name: record['name'] as String,
                contactPerson: Value(record['contact_person'] as String?),
                email: Value(record['email'] as String?),
                phone: Value(record['phone'] as String?),
                address: Value(record['address'] as String?),
                taxId: Value(record['tax_id'] as String?),
                paymentTermDays: Value(record['payment_term_days'] as int? ?? 30),
                notes: Value(record['notes'] as String?),
                isActive: Value(record['is_active'] as bool? ?? true),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'inventory':
        await _database.into(_database.inventory).insertOnConflictUpdate(
              InventoryCompanion.insert(
                id: record['id'] as String,
                productId: record['product_id'] as String,
                quantityOnHand: Value(record['quantity_on_hand'] as int? ?? 0),
                totalCost: Value((record['total_cost'] as num?)?.toDouble() ?? 0),
                reservedQuantity: Value(record['reserved_quantity'] as int? ?? 0),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'serial_numbers':
        await _database.into(_database.serialNumbers).insertOnConflictUpdate(
              SerialNumbersCompanion.insert(
                id: record['id'] as String,
                serialNumber: record['serial_number'] as String,
                productId: record['product_id'] as String,
                status: Value(record['status'] as String? ?? 'IN_STOCK'),
                unitCost: Value((record['unit_cost'] as num?)?.toDouble() ?? 0),
                grnId: Value(record['grn_id'] as String?),
                grnItemId: Value(record['grn_item_id'] as String?),
                saleId: Value(record['sale_id'] as String?),
                customerId: Value(record['customer_id'] as String?),
                notes: Value(record['notes'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;
    }
  }

  /// Adds an item to the sync queue
  Future<void> queueForSync({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _database.into(_database.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'sq_${DateTime.now().millisecondsSinceEpoch}',
            queueTableName: tableName,
            recordId: recordId,
            operation: operation,
            payload: jsonEncode(payload),
          ),
        );
  }

  /// Gets the count of pending sync items
  Future<int> getPendingSyncCount() async {
    final result = await (_database.select(_database.syncQueue)
          ..where((t) => t.processedAt.isNull()))
        .get();
    return result.length;
  }

  void dispose() {
    stopPeriodicSync();
  }
}
