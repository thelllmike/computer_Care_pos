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

    // Get all pending items from sync queue
    final pendingItems = await (_database.select(_database.syncQueue)
          ..where((t) => t.processedAt.isNull()))
        .get();

    for (final item in pendingItems) {
      try {
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;

        switch (item.operation) {
          case 'INSERT':
            await _supabaseClient.from(item.queueTableName).insert(payload);
            break;
          case 'UPDATE':
            await _supabaseClient
                .from(item.queueTableName)
                .update(payload)
                .eq('id', item.recordId);
            break;
          case 'DELETE':
            await _supabaseClient
                .from(item.queueTableName)
                .delete()
                .eq('id', item.recordId);
            break;
        }

        // Mark as processed
        await (_database.update(_database.syncQueue)
              ..where((t) => t.id.equals(item.id)))
            .write(SyncQueueCompanion(
          processedAt: Value(DateTime.now()),
        ));

        count++;
      } catch (e) {
        // Increment retry count
        await (_database.update(_database.syncQueue)
              ..where((t) => t.id.equals(item.id)))
            .write(SyncQueueCompanion(
          retryCount: Value(item.retryCount + 1),
          lastError: Value(e.toString()),
        ));

        errors.add('Failed to sync ${item.queueTableName}/${item.recordId}: $e');
      }
    }

    return (count: count, errors: errors);
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
          await _upsertRecord(table, record as Map<String, dynamic>);
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
    // Implementation depends on table structure
    // This is a simplified version - actual implementation would need
    // table-specific logic
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
                serverUpdatedAt: Value(DateTime.parse(record['updated_at'] as String)),
              ),
            );
        break;
      // Add cases for other tables...
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
