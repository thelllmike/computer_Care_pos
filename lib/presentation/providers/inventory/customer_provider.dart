import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/customer_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// DAO provider
final customerDaoProvider = Provider<CustomerDao>((ref) {
  final db = ref.watch(databaseProvider);
  return CustomerDao(db);
});

// All customers stream
final customersProvider = StreamProvider<List<Customer>>((ref) {
  final dao = ref.watch(customerDaoProvider);
  return dao.watchAllCustomers();
});

// Credit customers
final creditCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final dao = ref.watch(customerDaoProvider);
  return dao.getCreditCustomers();
});

// Customers with outstanding balance
final customersWithOutstandingProvider = FutureProvider<List<Customer>>((ref) async {
  final dao = ref.watch(customerDaoProvider);
  return dao.getCustomersWithOutstanding();
});

// Single customer by ID
final customerByIdProvider = FutureProvider.family<Customer?, String>((ref, id) async {
  final dao = ref.watch(customerDaoProvider);
  return dao.getCustomerById(id);
});

// Search customers
final customerSearchProvider = FutureProvider.family<List<Customer>, String>((ref, query) async {
  final dao = ref.watch(customerDaoProvider);
  if (query.isEmpty) return [];
  return dao.searchCustomers(query);
});

// Available credit for a customer
final customerAvailableCreditProvider = FutureProvider.family<double, String>((ref, customerId) async {
  final dao = ref.watch(customerDaoProvider);
  return dao.getAvailableCredit(customerId);
});

// Customer form state
class CustomerFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const CustomerFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  CustomerFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
  }) {
    return CustomerFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

// Customer form notifier
class CustomerFormNotifier extends StateNotifier<CustomerFormState> {
  final CustomerDao _dao;
  final AppDatabase _db;

  CustomerFormNotifier(this._dao, this._db) : super(const CustomerFormState());

  Future<Customer?> createCustomer({
    required String name,
    String? email,
    String? phone,
    String? address,
    String? nic,
    bool creditEnabled = false,
    double creditLimit = 0,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Generate code
      final code = await _db.getNextSequenceNumber('CUSTOMER');

      final customer = await _dao.insertCustomer(
        code: code,
        name: name,
        email: email,
        phone: phone,
        address: address,
        nic: nic,
        creditEnabled: creditEnabled,
        creditLimit: creditLimit,
        notes: notes,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
      return customer;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> updateCustomer({
    required String id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? nic,
    bool? creditEnabled,
    double? creditLimit,
    String? notes,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _dao.updateCustomer(
        id: id,
        name: name,
        email: email,
        phone: phone,
        address: address,
        nic: nic,
        creditEnabled: creditEnabled,
        creditLimit: creditLimit,
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

  Future<bool> deleteCustomer(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _dao.deleteCustomer(id);
      state = state.copyWith(isLoading: false, isSuccess: success);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = const CustomerFormState();
  }
}

final customerFormProvider = StateNotifierProvider<CustomerFormNotifier, CustomerFormState>((ref) {
  final dao = ref.watch(customerDaoProvider);
  final db = ref.watch(databaseProvider);
  return CustomerFormNotifier(dao, db);
});
