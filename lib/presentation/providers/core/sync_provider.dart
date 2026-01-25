import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/sync/sync_service.dart';
import 'database_provider.dart';
import 'supabase_provider.dart';

// Sync state
class SyncState {
  final bool isSyncing;
  final bool isOnline;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final String? lastError;
  final SyncResult? lastResult;

  const SyncState({
    this.isSyncing = false,
    this.isOnline = true,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastError,
    this.lastResult,
  });

  SyncState copyWith({
    bool? isSyncing,
    bool? isOnline,
    DateTime? lastSyncAt,
    int? pendingCount,
    String? lastError,
    SyncResult? lastResult,
    bool clearError = false,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

// Sync notifier
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncService _syncService;
  final AppDatabase _database;
  Timer? _statusTimer;

  SyncNotifier(this._syncService, this._database) : super(const SyncState()) {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity
    final isOnline = await _syncService.isOnline();
    state = state.copyWith(isOnline: isOnline);

    // Load last sync time and pending count
    await _refreshStatus();

    // Start periodic status check
    _statusTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshStatus(),
    );

    // Start auto sync if online
    if (isOnline) {
      _syncService.startPeriodicSync();
    }
  }

  Future<void> _refreshStatus() async {
    final isOnline = await _syncService.isOnline();
    final pendingCount = await _syncService.getPendingSyncCount();

    // Get last sync time from metadata
    final metadata = await _database.select(_database.syncMetadata).get();
    DateTime? lastSync;
    for (final meta in metadata) {
      if (meta.lastSyncAt != null) {
        if (lastSync == null || meta.lastSyncAt!.isAfter(lastSync)) {
          lastSync = meta.lastSyncAt;
        }
      }
    }

    state = state.copyWith(
      isOnline: isOnline,
      pendingCount: pendingCount,
      lastSyncAt: lastSync,
    );
  }

  // Manual sync trigger
  Future<SyncResult> syncNow() async {
    if (state.isSyncing) {
      return const SyncResult(
        success: false,
        errors: ['Sync already in progress'],
      );
    }

    state = state.copyWith(isSyncing: true, clearError: true);

    try {
      final result = await _syncService.sync();

      state = state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        lastResult: result,
        lastError: result.errors.isNotEmpty ? result.errors.join(', ') : null,
      );

      // Refresh pending count
      final pendingCount = await _syncService.getPendingSyncCount();
      state = state.copyWith(pendingCount: pendingCount);

      return result;
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        lastError: e.toString(),
      );
      return SyncResult(success: false, errors: [e.toString()]);
    }
  }

  // Push only (for when you want to upload changes without downloading)
  Future<SyncResult> pushChanges() async {
    if (state.isSyncing) {
      return const SyncResult(success: false, errors: ['Sync in progress']);
    }

    state = state.copyWith(isSyncing: true, clearError: true);

    try {
      final result = await _syncService.sync(direction: SyncDirection.push);
      await _refreshStatus();
      state = state.copyWith(isSyncing: false, lastResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(isSyncing: false, lastError: e.toString());
      return SyncResult(success: false, errors: [e.toString()]);
    }
  }

  // Pull only (for refreshing data from server)
  Future<SyncResult> pullChanges() async {
    if (state.isSyncing) {
      return const SyncResult(success: false, errors: ['Sync in progress']);
    }

    state = state.copyWith(isSyncing: true, clearError: true);

    try {
      final result = await _syncService.sync(direction: SyncDirection.pull);
      await _refreshStatus();
      state = state.copyWith(isSyncing: false, lastResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(isSyncing: false, lastError: e.toString());
      return SyncResult(success: false, errors: [e.toString()]);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _syncService.dispose();
    super.dispose();
  }
}

// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final database = ref.watch(databaseProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  return SyncService(
    database: database,
    supabaseClient: supabaseClient,
  );
});

// Sync notifier provider
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final database = ref.watch(databaseProvider);
  return SyncNotifier(syncService, database);
});

// Convenience providers
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncProvider).isSyncing;
});

final pendingSyncCountProvider = Provider<int>((ref) {
  return ref.watch(syncProvider).pendingCount;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(syncProvider).isOnline;
});
