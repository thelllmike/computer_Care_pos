import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/supplier_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// DAO provider
final supplierDaoProvider = Provider<SupplierDao>((ref) {
  final db = ref.watch(databaseProvider);
  return SupplierDao(db);
});

// All suppliers stream
final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final dao = ref.watch(supplierDaoProvider);
  return dao.watchAllSuppliers();
});

// Single supplier by ID
final supplierByIdProvider = FutureProvider.family<Supplier?, String>((ref, id) async {
  final dao = ref.watch(supplierDaoProvider);
  return dao.getSupplierById(id);
});

// Search suppliers
final supplierSearchProvider = FutureProvider.family<List<Supplier>, String>((ref, query) async {
  final dao = ref.watch(supplierDaoProvider);
  if (query.isEmpty) return [];
  return dao.searchSuppliers(query);
});

// Supplier form state
class SupplierFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const SupplierFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  SupplierFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
  }) {
    return SupplierFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

// Supplier form notifier
class SupplierFormNotifier extends StateNotifier<SupplierFormState> {
  final SupplierDao _dao;
  final AppDatabase _db;

  SupplierFormNotifier(this._dao, this._db) : super(const SupplierFormState());

  Future<Supplier?> createSupplier({
    required String name,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? taxId,
    int paymentTermDays = 30,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Generate code
      final code = await _db.getNextSequenceNumber('SUPPLIER');

      final supplier = await _dao.insertSupplier(
        code: code,
        name: name,
        contactPerson: contactPerson,
        email: email,
        phone: phone,
        address: address,
        taxId: taxId,
        paymentTermDays: paymentTermDays,
        notes: notes,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
      return supplier;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> updateSupplier({
    required String id,
    String? name,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? taxId,
    int? paymentTermDays,
    String? notes,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _dao.updateSupplier(
        id: id,
        name: name,
        contactPerson: contactPerson,
        email: email,
        phone: phone,
        address: address,
        taxId: taxId,
        paymentTermDays: paymentTermDays,
        notes: notes,
        isActive: isActive,
      );

      state = state.copyWith(isLoading: false, isSuccess: success);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteSupplier(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _dao.deleteSupplier(id);
      state = state.copyWith(isLoading: false, isSuccess: success);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = const SupplierFormState();
  }
}

final supplierFormProvider = StateNotifierProvider<SupplierFormNotifier, SupplierFormState>((ref) {
  final dao = ref.watch(supplierDaoProvider);
  final db = ref.watch(databaseProvider);
  return SupplierFormNotifier(dao, db);
});
