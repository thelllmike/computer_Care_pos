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

  /// Force full sync - resets timestamps and pulls ALL data from Supabase
  Future<SyncResult> forceFullSync() async {
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
      // First push any pending local changes
      final pushResult = await _pushChanges();
      pushedCount = pushResult.count;
      errors.addAll(pushResult.errors);

      // Reset all sync metadata to force full pull
      await resetSyncMetadata();

      // Pull ALL data (no timestamp filter since we cleared metadata)
      final pullResult = await _pullChanges();
      pulledCount = pullResult.count;
      errors.addAll(pullResult.errors);

      return SyncResult(
        success: errors.isEmpty,
        pushedCount: pushedCount,
        pulledCount: pulledCount,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        errors: ['Force full sync failed: $e'],
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Resets all sync metadata timestamps to allow full pull
  Future<void> resetSyncMetadata() async {
    // ignore: avoid_print
    print('[SYNC] Resetting all sync metadata for full pull...');
    await _database.delete(_database.syncMetadata).go();
    // ignore: avoid_print
    print('[SYNC] Sync metadata cleared.');
  }

  // ==================== PUSH ====================

  /// Pushes local pending changes to Supabase
  Future<({int count, List<String> errors})> _pushChanges() async {
    final errors = <String>[];
    var count = 0;

    // Push in dependency order (parent tables first)
    // Master data (parents first)
    count += await _pushPendingTable('categories', _database.categories, errors);
    count += await _pushPendingTable('suppliers', _database.suppliers, errors);
    count += await _pushPendingTable('customers', _database.customers, errors);
    count += await _pushPendingTable('products', _database.products, errors);
    count += await _pushPendingTable('inventory', _database.inventory, errors);
    count += await _pushPendingTable('serial_numbers', _database.serialNumbers, errors);
    // Purchasing
    count += await _pushPendingTable('purchase_orders', _database.purchaseOrders, errors);
    count += await _pushPendingTable('purchase_order_items', _database.purchaseOrderItems, errors);
    count += await _pushPendingTable('grn', _database.grn, errors);
    count += await _pushPendingTable('grn_items', _database.grnItems, errors);
    count += await _pushPendingTable('grn_serials', _database.grnSerials, errors);
    // Quotations
    count += await _pushPendingTable('quotations', _database.quotations, errors);
    count += await _pushPendingTable('quotation_items', _database.quotationItems, errors);
    // Sales + children
    count += await _pushPendingTable('sales', _database.sales, errors);
    count += await _pushPendingTable('sale_items', _database.saleItems, errors);
    count += await _pushPendingTable('sale_serials', _database.saleSerials, errors);
    count += await _pushPendingTable('payments', _database.payments, errors);
    count += await _pushPendingTable('credit_transactions', _database.creditTransactions, errors);
    // Repairs
    count += await _pushPendingTable('repair_jobs', _database.repairJobs, errors);
    count += await _pushPendingTable('repair_parts', _database.repairParts, errors);
    count += await _pushPendingTable('repair_status_history', _database.repairStatusHistory, errors);
    // Other transactions
    count += await _pushPendingTable('expenses', _database.expenses, errors);
    count += await _pushPendingTable('stock_losses', _database.stockLosses, errors);
    count += await _pushPendingTable('warranty_claims', _database.warrantyClaims, errors);
    count += await _pushPendingTable('warranty_claim_history', _database.warrantyClaimHistory, errors);
    count += await _pushPendingTable('serial_number_history', _database.serialNumberHistory, errors);

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
      // Get all records from the table
      final query = _database.select(table);
      final records = await query.get();

      for (final record in records) {
        final recordMap = (record as dynamic);

        // Only push records with PENDING sync status
        if (recordMap.syncStatus != 'PENDING') continue;

        // Convert to JSON for Supabase
        final data = _recordToJson(tableName, record);
        if (data == null) continue;

        try {
          // Upsert to Supabase
          await _supabaseClient
              .from(tableName)
              .upsert(data, onConflict: 'id');

          // Mark as synced
          await _markAsSynced(tableName, recordMap.id as String);
          count++;
        } catch (e) {
          final errorStr = e.toString();

          // Handle duplicate unique key errors (e.g. invoice_number on sales)
          if (errorStr.contains('23505') || errorStr.contains('duplicate key')) {
            final resolved = await _handleDuplicateKeyError(
              tableName, recordMap.id as String, data, e, errors,
            );
            if (resolved) {
              count++;
              continue;
            }
          }

          // Handle FK constraint errors - try to push with null FK if parent doesn't exist
          if (errorStr.contains('23503') || errorStr.contains('foreign key')) {
            final resolved = await _handleForeignKeyError(
              tableName, recordMap.id as String, data, e, errors,
            );
            if (resolved) {
              count++;
              continue;
            }
          }

          errors.add('Failed to push $tableName/${recordMap.id}: $e');
        }
      }
    } catch (e) {
      errors.add('Failed to query $tableName: $e');
    }

    return count;
  }

  /// Handle duplicate key errors during push
  Future<bool> _handleDuplicateKeyError(
    String tableName,
    String recordId,
    Map<String, dynamic> data,
    Object error,
    List<String> errors,
  ) async {
    try {
      // Check if the same record (by id) already exists in Supabase
      final existing = await _supabaseClient
          .from(tableName)
          .select('id')
          .eq('id', recordId)
          .maybeSingle();

      if (existing != null) {
        // Same record already exists - just mark as synced
        await _markAsSynced(tableName, recordId);
        return true;
      }

      // A different record has the same unique value (e.g. invoice_number).
      // For sales table, sync the sequence from Supabase and retry.
      if (tableName == 'sales' && data.containsKey('invoice_number')) {
        await _syncSequenceFromSupabase(
          tableName: 'sales',
          columnName: 'invoice_number',
          sequenceType: 'INVOICE',
          prefix: 'INV',
        );

        for (int attempt = 0; attempt < 5; attempt++) {
          final newInvoiceNumber =
              await _database.getNextSequenceNumber('INVOICE');
          data['invoice_number'] = newInvoiceNumber;

          await (_database.update(_database.sales)
                ..where((t) => t.id.equals(recordId)))
              .write(SalesCompanion(
            invoiceNumber: Value(newInvoiceNumber),
            localUpdatedAt: Value(DateTime.now()),
          ));

          try {
            await _supabaseClient
                .from(tableName)
                .upsert(data, onConflict: 'id');
            await _markAsSynced(tableName, recordId);
            return true;
          } catch (retryError) {
            final retryStr = retryError.toString();
            if ((retryStr.contains('23505') ||
                    retryStr.contains('duplicate key')) &&
                attempt < 4) {
              continue;
            }
            rethrow;
          }
        }
      }

      return false;
    } catch (e) {
      errors.add('Duplicate key resolution failed for $tableName/$recordId: $e');
      return false;
    }
  }

  /// Handle foreign key constraint errors by setting nullable FKs to null
  Future<bool> _handleForeignKeyError(
    String tableName,
    String recordId,
    Map<String, dynamic> data,
    Object error,
    List<String> errors,
  ) async {
    try {
      final errorStr = error.toString();

      // For products with missing category, set category_id to null
      if (tableName == 'products' && errorStr.contains('category_id')) {
        data['category_id'] = null;
        await _supabaseClient.from(tableName).upsert(data, onConflict: 'id');
        await _markAsSynced(tableName, recordId);
        return true;
      }

      // For other FK errors, we can't automatically resolve
      return false;
    } catch (e) {
      return false;
    }
  }

  // ==================== SEQUENCE SYNC ====================

  /// Syncs all local sequence numbers with Supabase on startup
  Future<void> syncSequencesFromSupabase() async {
    if (!await isOnline()) return;

    await Future.wait([
      _syncSequenceFromSupabase(
        tableName: 'sales',
        columnName: 'invoice_number',
        sequenceType: 'INVOICE',
        prefix: 'INV',
      ),
      _syncSequenceFromSupabase(
        tableName: 'repair_jobs',
        columnName: 'job_number',
        sequenceType: 'REPAIR_JOB',
        prefix: 'RJ',
      ),
      _syncSequenceFromSupabase(
        tableName: 'purchase_orders',
        columnName: 'order_number',
        sequenceType: 'PURCHASE_ORDER',
        prefix: 'PO',
      ),
      _syncSequenceFromSupabase(
        tableName: 'grn',
        columnName: 'grn_number',
        sequenceType: 'GRN',
        prefix: 'GRN',
      ),
      _syncSequenceFromSupabase(
        tableName: 'quotations',
        columnName: 'quotation_number',
        sequenceType: 'QUOTATION',
        prefix: 'QT',
      ),
      _syncSequenceFromSupabase(
        tableName: 'expenses',
        columnName: 'expense_number',
        sequenceType: 'EXPENSE',
        prefix: 'EXP',
      ),
      _syncSequenceFromSupabase(
        tableName: 'warranty_claims',
        columnName: 'claim_number',
        sequenceType: 'WARRANTY_CLAIM',
        prefix: 'WC',
      ),
      _syncSequenceFromSupabase(
        tableName: 'stock_losses',
        columnName: 'loss_number',
        sequenceType: 'STOCK_LOSS',
        prefix: 'LOSS',
      ),
    ]);
  }

  Future<void> _syncSequenceFromSupabase({
    required String tableName,
    required String columnName,
    required String sequenceType,
    required String prefix,
  }) async {
    try {
      final currentYear = DateTime.now().year;
      final pattern = '$prefix-$currentYear-%';

      final result = await _supabaseClient
          .from(tableName)
          .select(columnName)
          .like(columnName, pattern)
          .order(columnName, ascending: false)
          .limit(1)
          .maybeSingle();

      if (result != null && result[columnName] != null) {
        final value = result[columnName] as String;
        final parts = value.split('-');
        if (parts.length == 3) {
          final maxNumber = int.tryParse(parts[2]) ?? 0;
          await _database.syncSequenceNumber(
              sequenceType, currentYear, maxNumber);
        }
      }
    } catch (_) {
      // Non-critical
    }
  }

  // ==================== RECORD TO JSON ====================

  /// Convert a record to JSON for Supabase
  Map<String, dynamic>? _recordToJson(String tableName, dynamic record) {
    try {
      final now = DateTime.now().toIso8601String();
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
            'updated_at': now,
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
            'updated_at': now,
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
            'updated_at': now,
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
            'updated_at': now,
          };
        case 'inventory':
          return {
            'id': record.id,
            'product_id': record.productId,
            'quantity_on_hand': record.quantityOnHand,
            'total_cost': record.totalCost,
            'reserved_quantity': record.reservedQuantity,
            'last_stock_date': record.lastStockDate?.toIso8601String(),
            'updated_at': now,
          };
        case 'serial_numbers':
          return {
            'id': record.id,
            'serial_number': record.serialNumber,
            'product_id': record.productId,
            'status': record.status,
            'unit_cost': record.unitCost,
            'grn_id': record.grnId,
            'grn_item_id': record.grnItemId,
            'sale_id': record.saleId,
            'customer_id': record.customerId,
            'warranty_start_date': record.warrantyStartDate?.toIso8601String(),
            'warranty_end_date': record.warrantyEndDate?.toIso8601String(),
            'notes': record.notes,
            'updated_at': now,
          };
        case 'serial_number_history':
          return {
            'id': record.id,
            'serial_number_id': record.serialNumberId,
            'from_status': record.fromStatus,
            'to_status': record.toStatus,
            'reference_type': record.referenceType,
            'reference_id': record.referenceId,
            'notes': record.notes,
            'created_by': record.createdBy,
          };
        case 'purchase_orders':
          return {
            'id': record.id,
            'order_number': record.orderNumber,
            'supplier_id': record.supplierId,
            'order_date': record.orderDate.toIso8601String(),
            'expected_date': record.expectedDate?.toIso8601String(),
            'status': record.status,
            'total_amount': record.totalAmount,
            'notes': record.notes,
            'created_by': record.createdBy,
            'updated_at': now,
          };
        case 'purchase_order_items':
          return {
            'id': record.id,
            'purchase_order_id': record.purchaseOrderId,
            'product_id': record.productId,
            'quantity': record.quantity,
            'unit_cost': record.unitCost,
            'total_cost': record.totalCost,
            'received_quantity': record.receivedQuantity,
            'notes': record.notes,
            'updated_at': now,
          };
        case 'grn':
          return {
            'id': record.id,
            'grn_number': record.grnNumber,
            'purchase_order_id': record.purchaseOrderId,
            'supplier_id': record.supplierId,
            'invoice_number': record.invoiceNumber,
            'invoice_date': record.invoiceDate?.toIso8601String(),
            'received_date': record.receivedDate.toIso8601String(),
            'total_amount': record.totalAmount,
            'notes': record.notes,
            'received_by': record.receivedBy,
            'updated_at': now,
          };
        case 'grn_items':
          return {
            'id': record.id,
            'grn_id': record.grnId,
            'product_id': record.productId,
            'purchase_order_item_id': record.purchaseOrderItemId,
            'quantity': record.quantity,
            'unit_cost': record.unitCost,
            'notes': record.notes,
            'updated_at': now,
          };
        case 'grn_serials':
          return {
            'id': record.id,
            'grn_item_id': record.grnItemId,
            'serial_number_id': record.serialNumberId,
          };
        case 'quotations':
          return {
            'id': record.id,
            'quotation_number': record.quotationNumber,
            'customer_id': record.customerId,
            'quotation_date': record.quotationDate.toIso8601String(),
            'valid_until': record.validUntil?.toIso8601String(),
            'subtotal': record.subtotal,
            'discount_amount': record.discountAmount,
            'tax_amount': record.taxAmount,
            'total_amount': record.totalAmount,
            'status': record.status,
            'converted_sale_id': record.convertedSaleId,
            'notes': record.notes,
            'created_by': record.createdBy,
            'updated_at': now,
          };
        case 'quotation_items':
          return {
            'id': record.id,
            'quotation_id': record.quotationId,
            'product_id': record.productId,
            'quantity': record.quantity,
            'unit_price': record.unitPrice,
            'discount_amount': record.discountAmount,
            'total_price': record.totalPrice,
            'notes': record.notes,
            'updated_at': now,
          };
        case 'sales':
          return {
            'id': record.id,
            'invoice_number': record.invoiceNumber,
            'customer_id': record.customerId,
            'quotation_id': record.quotationId,
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
            'updated_at': now,
          };
        case 'sale_items':
          return {
            'id': record.id,
            'sale_id': record.saleId,
            'product_id': record.productId,
            'quantity': record.quantity,
            'unit_price': record.unitPrice,
            'unit_cost': record.unitCost,
            'discount_amount': record.discountAmount,
            'total_price': record.totalPrice,
            'total_cost': record.totalCost,
            'profit': record.profit,
            'updated_at': now,
          };
        case 'sale_serials':
          return {
            'id': record.id,
            'sale_item_id': record.saleItemId,
            'serial_number_id': record.serialNumberId,
            'serial_number': record.serialNumber,
            'unit_cost': record.unitCost,
          };
        case 'payments':
          return {
            'id': record.id,
            'sale_id': record.saleId,
            'payment_method': record.paymentMethod,
            'amount': record.amount,
            'reference_number': record.referenceNumber,
            'payment_date': record.paymentDate.toIso8601String(),
            'notes': record.notes,
            'received_by': record.receivedBy,
            'updated_at': now,
          };
        case 'credit_transactions':
          return {
            'id': record.id,
            'customer_id': record.customerId,
            'transaction_type': record.transactionType,
            'reference_type': record.referenceType,
            'reference_id': record.referenceId,
            'amount': record.amount,
            'balance_after': record.balanceAfter,
            'notes': record.notes,
            'created_by': record.createdBy,
            'transaction_date': record.transactionDate.toIso8601String(),
          };
        case 'repair_jobs':
          return {
            'id': record.id,
            'job_number': record.jobNumber,
            'customer_id': record.customerId,
            'manual_customer_name': record.manualCustomerName,
            'manual_customer_phone': record.manualCustomerPhone,
            'serial_number_id': record.serialNumberId,
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
            'is_under_warranty': record.isUnderWarranty,
            'warranty_notes': record.warrantyNotes,
            'received_date': record.receivedDate.toIso8601String(),
            'promised_date': record.promisedDate?.toIso8601String(),
            'completed_date': record.completedDate?.toIso8601String(),
            'delivered_date': record.deliveredDate?.toIso8601String(),
            'received_by': record.receivedBy,
            'assigned_to': record.assignedTo,
            'notes': record.notes,
            'invoice_id': record.invoiceId,
            'updated_at': now,
          };
        case 'repair_parts':
          return {
            'id': record.id,
            'repair_job_id': record.repairJobId,
            'product_id': record.productId,
            'serial_number_id': record.serialNumberId,
            'quantity': record.quantity,
            'unit_cost': record.unitCost,
            'unit_price': record.unitPrice,
            'total_cost': record.totalCost,
            'total_price': record.totalPrice,
            'updated_at': now,
          };
        case 'repair_status_history':
          return {
            'id': record.id,
            'repair_job_id': record.repairJobId,
            'from_status': record.fromStatus,
            'to_status': record.toStatus,
            'notes': record.notes,
            'changed_by': record.changedBy,
            'changed_at': record.changedAt.toIso8601String(),
          };
        case 'expenses':
          return {
            'id': record.id,
            'expense_number': record.expenseNumber,
            'category': record.category,
            'description': record.description,
            'amount': record.amount,
            'expense_date': record.expenseDate.toIso8601String(),
            'payment_method': record.paymentMethod,
            'reference_number': record.referenceNumber,
            'vendor': record.vendor,
            'notes': record.notes,
            'created_by': record.createdBy,
            'updated_at': now,
          };
        case 'stock_losses':
          return {
            'id': record.id,
            'loss_number': record.lossNumber,
            'product_id': record.productId,
            'quantity': record.quantity,
            'serial_number_id': record.serialNumberId,
            'loss_type': record.lossType,
            'loss_reason': record.lossReason,
            'unit_cost': record.unitCost,
            'total_loss_amount': record.totalLossAmount,
            'loss_date': record.lossDate.toIso8601String(),
            'notes': record.notes,
            'created_by': record.createdBy,
            'updated_at': now,
          };
        case 'warranty_claims':
          return {
            'id': record.id,
            'claim_number': record.claimNumber,
            'serial_number_id': record.serialNumberId,
            'supplier_id': record.supplierId,
            'claim_reason': record.claimReason,
            'status': record.status,
            'date_sent_to_supplier': record.dateSentToSupplier?.toIso8601String(),
            'expected_return_date': record.expectedReturnDate?.toIso8601String(),
            'actual_return_date': record.actualReturnDate?.toIso8601String(),
            'supplier_response': record.supplierResponse,
            'resolution_notes': record.resolutionNotes,
            'created_by': record.createdBy,
            'updated_at': now,
          };
        case 'warranty_claim_history':
          return {
            'id': record.id,
            'warranty_claim_id': record.warrantyClaimId,
            'from_status': record.fromStatus,
            'to_status': record.toStatus,
            'notes': record.notes,
            'changed_by': record.changedBy,
            'changed_at': record.changedAt.toIso8601String(),
          };
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ==================== MARK AS SYNCED ====================

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
      case 'serial_numbers':
        await (_database.update(_database.serialNumbers)
              ..where((t) => t.id.equals(id)))
            .write(SerialNumbersCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'serial_number_history':
        await (_database.update(_database.serialNumberHistory)
              ..where((t) => t.id.equals(id)))
            .write(SerialNumberHistoryCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'purchase_orders':
        await (_database.update(_database.purchaseOrders)
              ..where((t) => t.id.equals(id)))
            .write(PurchaseOrdersCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'purchase_order_items':
        await (_database.update(_database.purchaseOrderItems)
              ..where((t) => t.id.equals(id)))
            .write(PurchaseOrderItemsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'grn':
        await (_database.update(_database.grn)
              ..where((t) => t.id.equals(id)))
            .write(GrnCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'grn_items':
        await (_database.update(_database.grnItems)
              ..where((t) => t.id.equals(id)))
            .write(GrnItemsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'grn_serials':
        await (_database.update(_database.grnSerials)
              ..where((t) => t.id.equals(id)))
            .write(GrnSerialsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'quotations':
        await (_database.update(_database.quotations)
              ..where((t) => t.id.equals(id)))
            .write(QuotationsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'quotation_items':
        await (_database.update(_database.quotationItems)
              ..where((t) => t.id.equals(id)))
            .write(QuotationItemsCompanion(
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
      case 'sale_items':
        await (_database.update(_database.saleItems)
              ..where((t) => t.id.equals(id)))
            .write(SaleItemsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'sale_serials':
        await (_database.update(_database.saleSerials)
              ..where((t) => t.id.equals(id)))
            .write(SaleSerialsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'payments':
        await (_database.update(_database.payments)
              ..where((t) => t.id.equals(id)))
            .write(PaymentsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'credit_transactions':
        await (_database.update(_database.creditTransactions)
              ..where((t) => t.id.equals(id)))
            .write(CreditTransactionsCompanion(
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
      case 'repair_parts':
        await (_database.update(_database.repairParts)
              ..where((t) => t.id.equals(id)))
            .write(RepairPartsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'repair_status_history':
        await (_database.update(_database.repairStatusHistory)
              ..where((t) => t.id.equals(id)))
            .write(RepairStatusHistoryCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'expenses':
        await (_database.update(_database.expenses)
              ..where((t) => t.id.equals(id)))
            .write(ExpensesCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'stock_losses':
        await (_database.update(_database.stockLosses)
              ..where((t) => t.id.equals(id)))
            .write(StockLossesCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'warranty_claims':
        await (_database.update(_database.warrantyClaims)
              ..where((t) => t.id.equals(id)))
            .write(WarrantyClaimsCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
      case 'warranty_claim_history':
        await (_database.update(_database.warrantyClaimHistory)
              ..where((t) => t.id.equals(id)))
            .write(WarrantyClaimHistoryCompanion(
          syncStatus: const Value('SYNCED'),
          serverUpdatedAt: Value(now),
        ));
        break;
    }
  }

  // ==================== PULL ====================

  /// Gets the timestamp column name for a table
  static String _getTimestampColumn(String table) {
    // Tables that use created_at
    if (table == 'grn_serials' ||
        table == 'sale_serials' ||
        table == 'credit_transactions') {
      return 'created_at';
    }
    // Default: updated_at
    return 'updated_at';
  }

  /// Parses a date string and converts to local time if needed
  /// Supabase returns dates in UTC, we need local time for proper filtering
  static DateTime _parseLocalDate(String dateString) {
    final parsed = DateTime.parse(dateString);
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  /// Parses an optional date string and converts to local time if needed
  static DateTime? _parseLocalDateOrNull(String? dateString) {
    if (dateString == null) return null;
    return _parseLocalDate(dateString);
  }

  /// Pulls changes from Supabase to local database
  Future<({int count, List<String> errors})> _pullChanges() async {
    final errors = <String>[];
    var count = 0;

    // Pull in dependency order (parent tables first, then children)
    // NOTE: History tables (repair_status_history, warranty_claim_history, serial_number_history)
    // are NOT pulled - they are push-only since they're maintained locally
    final tables = [
      // Master data
      'categories',
      'products',
      'customers',
      'suppliers',
      'inventory',
      'serial_numbers',
      // Purchasing
      'purchase_orders',
      'purchase_order_items',
      'grn',
      'grn_items',
      'grn_serials',
      // Quotations
      'quotations',
      'quotation_items',
      // Sales + children
      'sales',
      'sale_items',
      'sale_serials',
      'payments',
      'credit_transactions',
      // Repairs
      'repair_jobs',
      'repair_parts',
      // Other transactions
      'expenses',
      'stock_losses',
      'warranty_claims',
    ];

    for (final table in tables) {
      try {
        final timestampColumn = _getTimestampColumn(table);

        // Get last sync time for this table
        final syncMeta = await (_database.select(_database.syncMetadata)
              ..where((t) => t.syncTableName.equals(table)))
            .getSingleOrNull();

        final lastSync = syncMeta?.lastSyncAt;

        // Fetch records updated/created since last sync
        var query = _supabaseClient.from(table).select();
        if (lastSync != null) {
          query = query.gt(timestampColumn, lastSync.toIso8601String());
        }

        final records = await query;

        // Debug log for key tables
        if (table == 'sales' || table == 'sale_items' || table == 'payments') {
          // ignore: avoid_print
          print('[SYNC] Pulling $table: ${records.length} records (lastSync: $lastSync)');
        }

        // Upsert records to local database
        for (final record in records) {
          try {
            await _upsertRecord(table, record);
            count++;
          } catch (e) {
            // ignore: avoid_print
            print('[SYNC ERROR] Failed to upsert $table/${record['id']}: $e');
            errors.add('Failed to upsert $table/${record['id']}: $e');
          }
        }

        // Update sync metadata
        if (syncMeta != null) {
          await (_database.update(_database.syncMetadata)
                ..where((t) => t.syncTableName.equals(table)))
              .write(SyncMetadataCompanion(
            lastSyncAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));
        } else {
          // Create sync metadata entry if it doesn't exist
          await _database.into(_database.syncMetadata).insert(
                SyncMetadataCompanion.insert(
                  id: 'sync_$table',
                  syncTableName: table,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      } catch (e) {
        // ignore: avoid_print
        print('[SYNC ERROR] Failed to pull $table: $e');
        errors.add('Failed to pull $table: $e');
      }
    }

    return (count: count, errors: errors);
  }

  // ==================== UPSERT RECORDS ====================

  /// Upserts a record to the local database based on table name
  Future<void> _upsertRecord(String table, Map<String, dynamic> record) async {
    // Tables use different timestamp columns
    final timestampField = _getTimestampColumn(table);
    final updatedAt = record[timestampField] != null
        ? DateTime.tryParse(record[timestampField] as String)
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

      case 'serial_number_history':
        await _database.into(_database.serialNumberHistory).insertOnConflictUpdate(
              SerialNumberHistoryCompanion.insert(
                id: record['id'] as String,
                serialNumberId: record['serial_number_id'] as String,
                fromStatus: record['from_status'] as String,
                toStatus: record['to_status'] as String,
                referenceType: Value(record['reference_type'] as String?),
                referenceId: Value(record['reference_id'] as String?),
                notes: Value(record['notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'purchase_orders':
        await _database.into(_database.purchaseOrders).insertOnConflictUpdate(
              PurchaseOrdersCompanion.insert(
                id: record['id'] as String,
                orderNumber: record['order_number'] as String,
                supplierId: record['supplier_id'] as String,
                orderDate: _parseLocalDate(record['order_date'] as String),
                expectedDate: Value(record['expected_date'] != null
                    ? DateTime.tryParse(record['expected_date'] as String)
                    : null),
                status: Value(record['status'] as String? ?? 'DRAFT'),
                totalAmount: Value((record['total_amount'] as num?)?.toDouble() ?? 0),
                notes: Value(record['notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'purchase_order_items':
        await _database.into(_database.purchaseOrderItems).insertOnConflictUpdate(
              PurchaseOrderItemsCompanion.insert(
                id: record['id'] as String,
                purchaseOrderId: record['purchase_order_id'] as String,
                productId: record['product_id'] as String,
                quantity: record['quantity'] as int,
                unitCost: (record['unit_cost'] as num).toDouble(),
                totalCost: (record['total_cost'] as num).toDouble(),
                receivedQuantity: Value(record['received_quantity'] as int? ?? 0),
                notes: Value(record['notes'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'grn':
        await _database.into(_database.grn).insertOnConflictUpdate(
              GrnCompanion.insert(
                id: record['id'] as String,
                grnNumber: record['grn_number'] as String,
                purchaseOrderId: Value(record['purchase_order_id'] as String?),
                supplierId: record['supplier_id'] as String,
                invoiceNumber: Value(record['invoice_number'] as String?),
                invoiceDate: Value(record['invoice_date'] != null
                    ? DateTime.tryParse(record['invoice_date'] as String)
                    : null),
                receivedDate: _parseLocalDate(record['received_date'] as String),
                totalAmount: Value((record['total_amount'] as num?)?.toDouble() ?? 0),
                notes: Value(record['notes'] as String?),
                receivedBy: Value(record['received_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'grn_items':
        await _database.into(_database.grnItems).insertOnConflictUpdate(
              GrnItemsCompanion.insert(
                id: record['id'] as String,
                grnId: record['grn_id'] as String,
                productId: record['product_id'] as String,
                purchaseOrderItemId: Value(record['purchase_order_item_id'] as String?),
                quantity: record['quantity'] as int,
                unitCost: (record['unit_cost'] as num).toDouble(),
                notes: Value(record['notes'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'grn_serials':
        await _database.into(_database.grnSerials).insertOnConflictUpdate(
              GrnSerialsCompanion.insert(
                id: record['id'] as String,
                grnItemId: record['grn_item_id'] as String,
                serialNumberId: record['serial_number_id'] as String,
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'quotations':
        await _database.into(_database.quotations).insertOnConflictUpdate(
              QuotationsCompanion.insert(
                id: record['id'] as String,
                quotationNumber: record['quotation_number'] as String,
                quotationDate: _parseLocalDate(record['quotation_date'] as String),
                customerId: Value(record['customer_id'] as String?),
                validUntil: Value(record['valid_until'] != null
                    ? DateTime.tryParse(record['valid_until'] as String)
                    : null),
                subtotal: Value((record['subtotal'] as num?)?.toDouble() ?? 0),
                discountAmount: Value((record['discount_amount'] as num?)?.toDouble() ?? 0),
                taxAmount: Value((record['tax_amount'] as num?)?.toDouble() ?? 0),
                totalAmount: Value((record['total_amount'] as num?)?.toDouble() ?? 0),
                status: Value(record['status'] as String? ?? 'DRAFT'),
                convertedSaleId: Value(record['converted_sale_id'] as String?),
                notes: Value(record['notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'quotation_items':
        await _database.into(_database.quotationItems).insertOnConflictUpdate(
              QuotationItemsCompanion.insert(
                id: record['id'] as String,
                quotationId: record['quotation_id'] as String,
                productId: record['product_id'] as String,
                quantity: record['quantity'] as int,
                unitPrice: (record['unit_price'] as num).toDouble(),
                discountAmount: Value((record['discount_amount'] as num?)?.toDouble() ?? 0),
                totalPrice: (record['total_price'] as num).toDouble(),
                notes: Value(record['notes'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'sales':
        await _database.into(_database.sales).insertOnConflictUpdate(
              SalesCompanion.insert(
                id: record['id'] as String,
                invoiceNumber: record['invoice_number'] as String,
                saleDate: _parseLocalDate(record['sale_date'] as String),
                customerId: Value(record['customer_id'] as String?),
                quotationId: Value(record['quotation_id'] as String?),
                subtotal: Value((record['subtotal'] as num?)?.toDouble() ?? 0),
                discountAmount: Value((record['discount_amount'] as num?)?.toDouble() ?? 0),
                taxAmount: Value((record['tax_amount'] as num?)?.toDouble() ?? 0),
                totalAmount: Value((record['total_amount'] as num?)?.toDouble() ?? 0),
                paidAmount: Value((record['paid_amount'] as num?)?.toDouble() ?? 0),
                totalCost: Value((record['total_cost'] as num?)?.toDouble() ?? 0),
                grossProfit: Value((record['gross_profit'] as num?)?.toDouble() ?? 0),
                isCredit: Value(record['is_credit'] as bool? ?? false),
                status: Value(record['status'] as String? ?? 'COMPLETED'),
                notes: Value(record['notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'sale_items':
        await _database.into(_database.saleItems).insertOnConflictUpdate(
              SaleItemsCompanion.insert(
                id: record['id'] as String,
                saleId: record['sale_id'] as String,
                productId: record['product_id'] as String,
                quantity: record['quantity'] as int,
                unitPrice: (record['unit_price'] as num).toDouble(),
                unitCost: (record['unit_cost'] as num).toDouble(),
                discountAmount: Value((record['discount_amount'] as num?)?.toDouble() ?? 0),
                totalPrice: (record['total_price'] as num).toDouble(),
                totalCost: (record['total_cost'] as num).toDouble(),
                profit: (record['profit'] as num).toDouble(),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'sale_serials':
        await _database.into(_database.saleSerials).insertOnConflictUpdate(
              SaleSerialsCompanion.insert(
                id: record['id'] as String,
                saleItemId: record['sale_item_id'] as String,
                serialNumberId: record['serial_number_id'] as String,
                serialNumber: record['serial_number'] as String,
                unitCost: (record['unit_cost'] as num).toDouble(),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'payments':
        await _database.into(_database.payments).insertOnConflictUpdate(
              PaymentsCompanion.insert(
                id: record['id'] as String,
                saleId: record['sale_id'] as String,
                paymentMethod: record['payment_method'] as String,
                amount: (record['amount'] as num).toDouble(),
                referenceNumber: Value(record['reference_number'] as String?),
                paymentDate: _parseLocalDate(record['payment_date'] as String),
                notes: Value(record['notes'] as String?),
                receivedBy: Value(record['received_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'credit_transactions':
        await _database.into(_database.creditTransactions).insertOnConflictUpdate(
              CreditTransactionsCompanion.insert(
                id: record['id'] as String,
                customerId: record['customer_id'] as String,
                transactionType: record['transaction_type'] as String,
                referenceType: Value(record['reference_type'] as String?),
                referenceId: Value(record['reference_id'] as String?),
                amount: (record['amount'] as num).toDouble(),
                balanceAfter: (record['balance_after'] as num).toDouble(),
                notes: Value(record['notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                transactionDate: _parseLocalDate(record['transaction_date'] as String),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'repair_jobs':
        await _database.into(_database.repairJobs).insertOnConflictUpdate(
              RepairJobsCompanion.insert(
                id: record['id'] as String,
                jobNumber: record['job_number'] as String,
                customerId: Value(record['customer_id'] as String?),
                manualCustomerName: Value(record['manual_customer_name'] as String?),
                manualCustomerPhone: Value(record['manual_customer_phone'] as String?),
                serialNumberId: Value(record['serial_number_id'] as String?),
                deviceType: record['device_type'] as String,
                deviceBrand: Value(record['device_brand'] as String?),
                deviceModel: Value(record['device_model'] as String?),
                deviceSerial: Value(record['device_serial'] as String?),
                problemDescription: record['problem_description'] as String,
                diagnosis: Value(record['diagnosis'] as String?),
                estimatedCost: Value((record['estimated_cost'] as num?)?.toDouble() ?? 0),
                actualCost: Value((record['actual_cost'] as num?)?.toDouble() ?? 0),
                laborCost: Value((record['labor_cost'] as num?)?.toDouble() ?? 0),
                partsCost: Value((record['parts_cost'] as num?)?.toDouble() ?? 0),
                totalCost: Value((record['total_cost'] as num?)?.toDouble() ?? 0),
                status: Value(record['status'] as String? ?? 'RECEIVED'),
                isUnderWarranty: Value(record['is_under_warranty'] as bool? ?? false),
                warrantyNotes: Value(record['warranty_notes'] as String?),
                receivedDate: _parseLocalDate(record['received_date'] as String),
                promisedDate: Value(record['promised_date'] != null
                    ? DateTime.tryParse(record['promised_date'] as String)
                    : null),
                completedDate: Value(record['completed_date'] != null
                    ? DateTime.tryParse(record['completed_date'] as String)
                    : null),
                deliveredDate: Value(record['delivered_date'] != null
                    ? DateTime.tryParse(record['delivered_date'] as String)
                    : null),
                receivedBy: Value(record['received_by'] as String?),
                assignedTo: Value(record['assigned_to'] as String?),
                notes: Value(record['notes'] as String?),
                invoiceId: Value(record['invoice_id'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'repair_parts':
        await _database.into(_database.repairParts).insertOnConflictUpdate(
              RepairPartsCompanion.insert(
                id: record['id'] as String,
                repairJobId: record['repair_job_id'] as String,
                productId: record['product_id'] as String,
                serialNumberId: Value(record['serial_number_id'] as String?),
                quantity: record['quantity'] as int,
                unitCost: (record['unit_cost'] as num).toDouble(),
                unitPrice: (record['unit_price'] as num).toDouble(),
                totalCost: (record['total_cost'] as num).toDouble(),
                totalPrice: (record['total_price'] as num).toDouble(),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'repair_status_history':
        await _database.into(_database.repairStatusHistory).insertOnConflictUpdate(
              RepairStatusHistoryCompanion.insert(
                id: record['id'] as String,
                repairJobId: record['repair_job_id'] as String,
                fromStatus: Value(record['from_status'] as String?),
                toStatus: record['to_status'] as String,
                notes: Value(record['notes'] as String?),
                changedBy: Value(record['changed_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'expenses':
        await _database.into(_database.expenses).insertOnConflictUpdate(
              ExpensesCompanion.insert(
                id: record['id'] as String,
                expenseNumber: record['expense_number'] as String,
                category: record['category'] as String,
                description: record['description'] as String,
                amount: (record['amount'] as num).toDouble(),
                expenseDate: _parseLocalDate(record['expense_date'] as String),
                paymentMethod: Value(record['payment_method'] as String?),
                referenceNumber: Value(record['reference_number'] as String?),
                vendor: Value(record['vendor'] as String?),
                notes: Value(record['notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'stock_losses':
        await _database.into(_database.stockLosses).insertOnConflictUpdate(
              StockLossesCompanion.insert(
                id: record['id'] as String,
                lossNumber: record['loss_number'] as String,
                productId: record['product_id'] as String,
                quantity: record['quantity'] as int,
                serialNumberId: Value(record['serial_number_id'] as String?),
                lossType: record['loss_type'] as String,
                lossReason: record['loss_reason'] as String,
                unitCost: (record['unit_cost'] as num).toDouble(),
                totalLossAmount: (record['total_loss_amount'] as num).toDouble(),
                lossDate: _parseLocalDate(record['loss_date'] as String),
                notes: Value(record['notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'warranty_claims':
        await _database.into(_database.warrantyClaims).insertOnConflictUpdate(
              WarrantyClaimsCompanion.insert(
                id: record['id'] as String,
                claimNumber: record['claim_number'] as String,
                serialNumberId: record['serial_number_id'] as String,
                supplierId: record['supplier_id'] as String,
                claimReason: record['claim_reason'] as String,
                status: Value(record['status'] as String? ?? 'PENDING'),
                dateSentToSupplier: Value(record['date_sent_to_supplier'] != null
                    ? DateTime.tryParse(record['date_sent_to_supplier'] as String)
                    : null),
                expectedReturnDate: Value(record['expected_return_date'] != null
                    ? DateTime.tryParse(record['expected_return_date'] as String)
                    : null),
                actualReturnDate: Value(record['actual_return_date'] != null
                    ? DateTime.tryParse(record['actual_return_date'] as String)
                    : null),
                supplierResponse: Value(record['supplier_response'] as String?),
                resolutionNotes: Value(record['resolution_notes'] as String?),
                createdBy: Value(record['created_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;

      case 'warranty_claim_history':
        await _database.into(_database.warrantyClaimHistory).insertOnConflictUpdate(
              WarrantyClaimHistoryCompanion.insert(
                id: record['id'] as String,
                warrantyClaimId: record['warranty_claim_id'] as String,
                fromStatus: Value(record['from_status'] as String?),
                toStatus: record['to_status'] as String,
                notes: Value(record['notes'] as String?),
                changedBy: Value(record['changed_by'] as String?),
                syncStatus: const Value('SYNCED'),
                serverUpdatedAt: Value(updatedAt),
              ),
            );
        break;
    }
  }

  // ==================== UTILITIES ====================

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
