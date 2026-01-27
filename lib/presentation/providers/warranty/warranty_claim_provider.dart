import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/warranty_claim_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/local/tables/warranty_claims_table.dart';
import '../core/database_provider.dart';

// DAO provider
final warrantyClaimDaoProvider = Provider<WarrantyClaimDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.warrantyClaimDao;
});

// Provider for all warranty claims
final warrantyClaimsProvider =
    FutureProvider<List<WarrantyClaimWithDetails>>((ref) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.getAllWarrantyClaims();
});

// Provider for active warranty claims
final activeWarrantyClaimsProvider =
    FutureProvider<List<WarrantyClaimWithDetails>>((ref) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.getActiveWarrantyClaims();
});

// Provider for warranty claims by status
final warrantyClaimsByStatusProvider = FutureProvider.family<
    List<WarrantyClaimWithDetails>, WarrantyClaimStatus>((ref, status) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.getWarrantyClaimsByStatus(status);
});

// Provider for warranty claim detail
final warrantyClaimDetailProvider =
    FutureProvider.family<WarrantyClaimWithDetails?, String>((ref, id) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.getWarrantyClaimDetail(id);
});

// Provider for warranty summary
final warrantySummaryProvider = FutureProvider<WarrantySummary>((ref) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.getWarrantySummary();
});

// Provider for claim history
final warrantyClaimHistoryProvider =
    FutureProvider.family<List<WarrantyClaimHistoryData>, String>(
        (ref, claimId) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.getClaimHistory(claimId);
});

// Provider for sold items under warranty (for creating new claims)
final soldItemsUnderWarrantyProvider =
    FutureProvider<List<SerialNumberWithProduct>>((ref) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.getSoldItemsUnderWarranty();
});

// Provider for searching serials for warranty
final searchSerialsForWarrantyProvider =
    FutureProvider.family<List<SerialNumberWithProduct>, String>((ref, query) {
  final dao = ref.watch(warrantyClaimDaoProvider);
  return dao.searchSerialsForWarranty(query);
});

// ==================== Warranty Claim Form State ====================

class WarrantyClaimFormState {
  final String? serialNumberId;
  final String? serialNumber;
  final String? productName;
  final String? supplierId;
  final String? supplierName;
  final String claimReason;
  final bool isSaving;
  final String? error;

  WarrantyClaimFormState({
    this.serialNumberId,
    this.serialNumber,
    this.productName,
    this.supplierId,
    this.supplierName,
    this.claimReason = '',
    this.isSaving = false,
    this.error,
  });

  bool get isValid =>
      serialNumberId != null &&
      serialNumberId!.isNotEmpty &&
      supplierId != null &&
      supplierId!.isNotEmpty &&
      claimReason.isNotEmpty;

  WarrantyClaimFormState copyWith({
    String? serialNumberId,
    String? serialNumber,
    String? productName,
    String? supplierId,
    String? supplierName,
    String? claimReason,
    bool? isSaving,
    String? error,
  }) {
    return WarrantyClaimFormState(
      serialNumberId: serialNumberId ?? this.serialNumberId,
      serialNumber: serialNumber ?? this.serialNumber,
      productName: productName ?? this.productName,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      claimReason: claimReason ?? this.claimReason,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class WarrantyClaimFormNotifier extends StateNotifier<WarrantyClaimFormState> {
  final AppDatabase _db;
  final Ref _ref;

  WarrantyClaimFormNotifier(this._db, this._ref)
      : super(WarrantyClaimFormState());

  void setSerialNumber(
      String serialId, String serialNumber, String productName) {
    state = state.copyWith(
      serialNumberId: serialId,
      serialNumber: serialNumber,
      productName: productName,
    );
  }

  void setSupplier(String supplierId, String supplierName) {
    state = state.copyWith(
      supplierId: supplierId,
      supplierName: supplierName,
    );
  }

  void setClaimReason(String reason) {
    state = state.copyWith(claimReason: reason);
  }

  Future<WarrantyClaim?> saveWarrantyClaim({String? createdBy}) async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Please fill in all required fields');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final claim = await _db.warrantyClaimDao.createWarrantyClaim(
        serialNumberId: state.serialNumberId!,
        supplierId: state.supplierId!,
        claimReason: state.claimReason,
        createdBy: createdBy,
      );

      // Invalidate providers
      _ref.invalidate(warrantyClaimsProvider);
      _ref.invalidate(activeWarrantyClaimsProvider);
      _ref.invalidate(warrantySummaryProvider);

      state = state.copyWith(isSaving: false);
      return claim;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  void clear() {
    state = WarrantyClaimFormState();
  }
}

final warrantyClaimFormProvider =
    StateNotifierProvider<WarrantyClaimFormNotifier, WarrantyClaimFormState>(
        (ref) {
  final db = ref.watch(databaseProvider);
  return WarrantyClaimFormNotifier(db, ref);
});

// ==================== Status Update State ====================

class WarrantyStatusUpdateState {
  final String? claimId;
  final WarrantyClaimStatus? newStatus;
  final DateTime? dateSentToSupplier;
  final DateTime? expectedReturnDate;
  final DateTime? actualReturnDate;
  final String? supplierResponse;
  final String? resolutionNotes;
  final bool isSaving;
  final String? error;

  WarrantyStatusUpdateState({
    this.claimId,
    this.newStatus,
    this.dateSentToSupplier,
    this.expectedReturnDate,
    this.actualReturnDate,
    this.supplierResponse,
    this.resolutionNotes,
    this.isSaving = false,
    this.error,
  });

  bool get isValid => claimId != null && newStatus != null;

  WarrantyStatusUpdateState copyWith({
    String? claimId,
    WarrantyClaimStatus? newStatus,
    DateTime? dateSentToSupplier,
    DateTime? expectedReturnDate,
    DateTime? actualReturnDate,
    String? supplierResponse,
    String? resolutionNotes,
    bool? isSaving,
    String? error,
  }) {
    return WarrantyStatusUpdateState(
      claimId: claimId ?? this.claimId,
      newStatus: newStatus ?? this.newStatus,
      dateSentToSupplier: dateSentToSupplier ?? this.dateSentToSupplier,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      supplierResponse: supplierResponse ?? this.supplierResponse,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class WarrantyStatusUpdateNotifier
    extends StateNotifier<WarrantyStatusUpdateState> {
  final AppDatabase _db;
  final Ref _ref;

  WarrantyStatusUpdateNotifier(this._db, this._ref)
      : super(WarrantyStatusUpdateState());

  void setClaimId(String claimId) {
    state = state.copyWith(claimId: claimId);
  }

  void setNewStatus(WarrantyClaimStatus status) {
    state = state.copyWith(newStatus: status);
  }

  void setDateSentToSupplier(DateTime? date) {
    state = state.copyWith(dateSentToSupplier: date);
  }

  void setExpectedReturnDate(DateTime? date) {
    state = state.copyWith(expectedReturnDate: date);
  }

  void setActualReturnDate(DateTime? date) {
    state = state.copyWith(actualReturnDate: date);
  }

  void setSupplierResponse(String? response) {
    state = state.copyWith(supplierResponse: response);
  }

  void setResolutionNotes(String? notes) {
    state = state.copyWith(resolutionNotes: notes);
  }

  Future<bool> updateStatus({String? changedBy}) async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Please select a new status');
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final success = await _db.warrantyClaimDao.updateWarrantyClaimStatus(
        id: state.claimId!,
        newStatus: state.newStatus!,
        dateSentToSupplier: state.dateSentToSupplier,
        expectedReturnDate: state.expectedReturnDate,
        actualReturnDate: state.actualReturnDate,
        supplierResponse: state.supplierResponse,
        resolutionNotes: state.resolutionNotes,
        changedBy: changedBy,
      );

      // Invalidate providers
      _ref.invalidate(warrantyClaimsProvider);
      _ref.invalidate(activeWarrantyClaimsProvider);
      _ref.invalidate(warrantySummaryProvider);
      _ref.invalidate(warrantyClaimDetailProvider(state.claimId!));
      _ref.invalidate(warrantyClaimHistoryProvider(state.claimId!));

      state = state.copyWith(isSaving: false);
      return success;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  void clear() {
    state = WarrantyStatusUpdateState();
  }
}

final warrantyStatusUpdateProvider = StateNotifierProvider<
    WarrantyStatusUpdateNotifier, WarrantyStatusUpdateState>((ref) {
  final db = ref.watch(databaseProvider);
  return WarrantyStatusUpdateNotifier(db, ref);
});
