import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/serial_status.dart';
import '../../../data/local/daos/inventory_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// Provider for all inventory with product details
final inventoryProvider = StreamProvider<List<InventoryWithProduct>>((ref) {
  final db = ref.watch(databaseProvider);
  return Stream.fromFuture(db.inventoryDao.getAllInventoryWithProducts());
});

// Provider for low stock items
final lowStockProvider = FutureProvider<List<InventoryWithProduct>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.getLowStockItems();
});

// Provider for inventory of a specific product
final productInventoryProvider = StreamProvider.family<InventoryData?, String>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.watchInventoryByProductId(productId);
});

// Provider for available serial numbers for a product
final availableSerialNumbersProvider = StreamProvider.family<List<SerialNumber>, String>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.watchAvailableSerialNumbers(productId);
});

// Provider for all serial numbers for a product
final productSerialNumbersProvider = FutureProvider.family<List<SerialNumber>, String>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.getSerialNumbersByProduct(productId);
});

// Provider for serial numbers by status
final serialNumbersByStatusProvider = FutureProvider.family<List<SerialNumber>, SerialStatus>((ref, status) {
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.getSerialNumbersByStatus(status);
});

// Provider for serial numbers by customer
final customerSerialNumbersProvider = FutureProvider.family<List<SerialNumber>, String>((ref, customerId) {
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.getSerialNumbersByCustomer(customerId);
});

// Provider for serial number history
final serialHistoryProvider = FutureProvider.family<List<SerialNumberHistoryData>, String>((ref, serialId) {
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.getSerialHistory(serialId);
});

// Search serial numbers
final serialSearchProvider = FutureProvider.family<List<SerialNumber>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  final db = ref.watch(databaseProvider);
  return db.inventoryDao.searchSerialNumbers(query);
});

// State class for inventory adjustments
class InventoryAdjustmentState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  InventoryAdjustmentState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  InventoryAdjustmentState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
  }) {
    return InventoryAdjustmentState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

// Notifier for inventory adjustments
class InventoryAdjustmentNotifier extends StateNotifier<InventoryAdjustmentState> {
  final AppDatabase _db;
  final Ref _ref;

  InventoryAdjustmentNotifier(this._db, this._ref) : super(InventoryAdjustmentState());

  // Adjust inventory quantity
  Future<void> adjustInventory({
    required String productId,
    required int quantityChange,
    required double costChange,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.inventoryDao.updateInventory(
        productId: productId,
        quantityChange: quantityChange,
        costChange: costChange,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(inventoryProvider);
      _ref.invalidate(productInventoryProvider(productId));
      _ref.invalidate(lowStockProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Set inventory directly (admin only)
  Future<void> setInventory({
    required String productId,
    required int quantity,
    required double totalCost,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.inventoryDao.setInventory(
        productId: productId,
        quantity: quantity,
        totalCost: totalCost,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(inventoryProvider);
      _ref.invalidate(productInventoryProvider(productId));
      _ref.invalidate(lowStockProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Update serial number status
  Future<void> updateSerialStatus({
    required String serialId,
    required SerialStatus newStatus,
    String? saleId,
    String? customerId,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    String? referenceType,
    String? referenceId,
    String? notes,
    String? changedBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.inventoryDao.updateSerialStatus(
        serialId: serialId,
        newStatus: newStatus,
        saleId: saleId,
        customerId: customerId,
        warrantyStartDate: warrantyStartDate,
        warrantyEndDate: warrantyEndDate,
        referenceType: referenceType,
        referenceId: referenceId,
        notes: notes,
        changedBy: changedBy,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(inventoryProvider);
      _ref.invalidate(lowStockProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = InventoryAdjustmentState();
  }
}

// Provider for inventory adjustments
final inventoryAdjustmentProvider = StateNotifierProvider<InventoryAdjustmentNotifier, InventoryAdjustmentState>((ref) {
  final db = ref.watch(databaseProvider);
  return InventoryAdjustmentNotifier(db, ref);
});

// Helper class for displaying inventory stats
class InventoryStats {
  final int totalProducts;
  final int lowStockCount;
  final double totalValue;
  final int serializedCount;

  InventoryStats({
    required this.totalProducts,
    required this.lowStockCount,
    required this.totalValue,
    required this.serializedCount,
  });
}

// Provider for inventory statistics
final inventoryStatsProvider = FutureProvider<InventoryStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final allInventory = await db.inventoryDao.getAllInventoryWithProducts();
  final lowStock = await db.inventoryDao.getLowStockItems();
  final serialized = await db.inventoryDao.getSerialNumbersByStatus(SerialStatus.inStock);

  double totalValue = 0;
  for (final item in allInventory) {
    totalValue += item.totalCost;
  }

  return InventoryStats(
    totalProducts: allInventory.length,
    lowStockCount: lowStock.length,
    totalValue: totalValue,
    serializedCount: serialized.length,
  );
});
