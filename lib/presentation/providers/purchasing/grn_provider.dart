import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/grn_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// Provider for all GRNs
final grnsProvider = StreamProvider<List<GrnWithSupplier>>((ref) {
  final db = ref.watch(databaseProvider);
  return Stream.fromFuture(db.grnDao.getAllGrns());
});

// Provider for a single GRN detail
final grnDetailProvider = FutureProvider.family<GrnDetail?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.grnDao.getGrnDetail(id);
});

// State class for GRN form
class GrnFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final GrnData? createdGrn;
  final List<String> duplicateSerials;

  GrnFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.createdGrn,
    this.duplicateSerials = const [],
  });

  GrnFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    GrnData? createdGrn,
    List<String>? duplicateSerials,
  }) {
    return GrnFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      createdGrn: createdGrn ?? this.createdGrn,
      duplicateSerials: duplicateSerials ?? this.duplicateSerials,
    );
  }
}

// Notifier for GRN form operations
class GrnFormNotifier extends StateNotifier<GrnFormState> {
  final AppDatabase _db;
  final Ref _ref;

  GrnFormNotifier(this._db, this._ref) : super(GrnFormState());

  Future<void> createGrn({
    required String supplierId,
    String? purchaseOrderId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? notes,
    String? receivedBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final grn = await _db.grnDao.createGrn(
        supplierId: supplierId,
        purchaseOrderId: purchaseOrderId,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        notes: notes,
        receivedBy: receivedBy,
      );
      state = state.copyWith(isLoading: false, isSuccess: true, createdGrn: grn);
      _ref.invalidate(grnsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateGrn({
    required String id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.grnDao.updateGrn(
        id: id,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        notes: notes,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(grnsProvider);
      _ref.invalidate(grnDetailProvider(id));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Add non-serialized item
  Future<void> addItem({
    required String grnId,
    required String productId,
    required int quantity,
    required double unitCost,
    String? purchaseOrderItemId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _db.grnDao.addGrnItem(
        grnId: grnId,
        productId: productId,
        quantity: quantity,
        unitCost: unitCost,
        purchaseOrderItemId: purchaseOrderItemId,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(grnDetailProvider(grnId));
      _ref.invalidate(grnsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Add serialized item (laptops)
  Future<void> addSerializedItem({
    required String grnId,
    required String productId,
    required List<String> serialNumbers,
    required double unitCost,
    String? purchaseOrderItemId,
    String? createdBy,
  }) async {
    state = state.copyWith(isLoading: true, error: null, duplicateSerials: []);
    try {
      // Validate serial numbers first
      final duplicates = await _db.grnDao.validateSerialNumbers(serialNumbers);
      if (duplicates.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Duplicate serial numbers found: ${duplicates.join(", ")}',
          duplicateSerials: duplicates,
        );
        return;
      }

      await _db.grnDao.addGrnItemWithSerials(
        grnId: grnId,
        productId: productId,
        serialNumbers: serialNumbers,
        unitCost: unitCost,
        purchaseOrderItemId: purchaseOrderItemId,
        createdBy: createdBy,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
      _ref.invalidate(grnDetailProvider(grnId));
      _ref.invalidate(grnsProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Validate serial numbers before submission
  Future<List<String>> validateSerials(List<String> serialNumbers) async {
    return _db.grnDao.validateSerialNumbers(serialNumbers);
  }

  // Check if a single serial exists
  Future<bool> isSerialExists(String serial) async {
    return _db.grnDao.isSerialNumberExists(serial);
  }

  void reset() {
    state = GrnFormState();
  }
}

// Provider for GRN form operations
final grnFormProvider = StateNotifierProvider<GrnFormNotifier, GrnFormState>((ref) {
  final db = ref.watch(databaseProvider);
  return GrnFormNotifier(db, ref);
});
