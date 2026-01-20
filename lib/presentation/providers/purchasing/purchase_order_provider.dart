import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/order_status.dart';
import '../../../data/local/daos/purchase_order_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// Provider for all purchase orders
final purchaseOrdersProvider = StreamProvider<List<PurchaseOrderWithSupplier>>((ref) {
  final db = ref.watch(databaseProvider);
  // Use a stream that refreshes when needed
  return Stream.fromFuture(db.purchaseOrderDao.getAllPurchaseOrders());
});

// Provider for purchase orders by status
final purchaseOrdersByStatusProvider = FutureProvider.family<List<PurchaseOrderWithSupplier>, OrderStatus>((ref, status) {
  final db = ref.watch(databaseProvider);
  return db.purchaseOrderDao.getPurchaseOrdersByStatus(status);
});

// Provider for a single purchase order detail
final purchaseOrderDetailProvider = FutureProvider.family<PurchaseOrderDetail?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.purchaseOrderDao.getPurchaseOrderDetail(id);
});

// Provider for pending POs by supplier
final pendingOrdersBySupplierProvider = FutureProvider.family<List<PurchaseOrder>, String>((ref, supplierId) {
  final db = ref.watch(databaseProvider);
  return db.purchaseOrderDao.getPendingOrdersBySupplier(supplierId);
});

// State class for PO form
class PurchaseOrderFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final PurchaseOrder? createdPO;

  PurchaseOrderFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.createdPO,
  });

  PurchaseOrderFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    PurchaseOrder? createdPO,
  }) {
    return PurchaseOrderFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      createdPO: createdPO ?? this.createdPO,
    );
  }
}

// Notifier for PO form operations
class PurchaseOrderFormNotifier extends StateNotifier<PurchaseOrderFormState> {
  final AppDatabase _db;
  final Ref _ref;

  PurchaseOrderFormNotifier(this._db, this._ref) : super(PurchaseOrderFormState());

  Future<void> createPurchaseOrder({
    required String supplierId,
    String? notes,
    String? createdBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final po = await _db.purchaseOrderDao.createPurchaseOrder(
        supplierId: supplierId,
        notes: notes,
        createdBy: createdBy,
      );
      state = state.copyWith(isLoading: false, isSuccess: true, createdPO: po);
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePurchaseOrder({
    required String id,
    String? supplierId,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.purchaseOrderDao.updatePurchaseOrder(
        id: id,
        supplierId: supplierId,
        notes: notes,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(purchaseOrdersProvider);
      _ref.invalidate(purchaseOrderDetailProvider(id));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateStatus(String id, OrderStatus status) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.purchaseOrderDao.updatePurchaseOrderStatus(id, status);
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(purchaseOrdersProvider);
      _ref.invalidate(purchaseOrderDetailProvider(id));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deletePurchaseOrder(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _db.purchaseOrderDao.deletePurchaseOrder(id);
      if (!success) {
        state = state.copyWith(isLoading: false, error: 'Cannot delete confirmed purchase orders');
        return;
      }
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addItem({
    required String purchaseOrderId,
    required String productId,
    required int quantity,
    required double unitCost,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.purchaseOrderDao.addPurchaseOrderItem(
        purchaseOrderId: purchaseOrderId,
        productId: productId,
        quantity: quantity,
        unitCost: unitCost,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(purchaseOrderDetailProvider(purchaseOrderId));
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateItem({
    required String itemId,
    required String purchaseOrderId,
    int? quantity,
    double? unitCost,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.purchaseOrderDao.updatePurchaseOrderItem(
        id: itemId,
        quantity: quantity,
        unitCost: unitCost,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(purchaseOrderDetailProvider(purchaseOrderId));
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteItem(String itemId, String purchaseOrderId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.purchaseOrderDao.deletePurchaseOrderItem(itemId);
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(purchaseOrderDetailProvider(purchaseOrderId));
      _ref.invalidate(purchaseOrdersProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = PurchaseOrderFormState();
  }
}

// Provider for PO form operations
final purchaseOrderFormProvider = StateNotifierProvider<PurchaseOrderFormNotifier, PurchaseOrderFormState>((ref) {
  final db = ref.watch(databaseProvider);
  return PurchaseOrderFormNotifier(db, ref);
});
