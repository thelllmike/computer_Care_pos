import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../tables/customers_table.dart';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers])
class CustomerDao extends DatabaseAccessor<AppDatabase> with _$CustomerDaoMixin {
  CustomerDao(super.db);

  static const _uuid = Uuid();

  // Get all active customers
  Future<List<Customer>> getAllCustomers() {
    return (select(customers)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Watch all active customers
  Stream<List<Customer>> watchAllCustomers() {
    return (select(customers)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  // Get customer by ID
  Future<Customer?> getCustomerById(String id) {
    return (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get customer by code
  Future<Customer?> getCustomerByCode(String code) {
    return (select(customers)..where((t) => t.code.equals(code))).getSingleOrNull();
  }

  // Get customers with credit enabled
  Future<List<Customer>> getCreditCustomers() {
    return (select(customers)
          ..where((t) => t.creditEnabled.equals(true) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Get customers with outstanding balance
  Future<List<Customer>> getCustomersWithOutstanding() {
    return (select(customers)
          ..where((t) => t.creditBalance.isBiggerThanValue(0) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.creditBalance)]))
        .get();
  }

  // Insert customer
  Future<Customer> insertCustomer({
    required String code,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? nic,
    bool creditEnabled = false,
    double creditLimit = 0,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(customers).insert(CustomersCompanion.insert(
      id: id,
      code: code,
      name: name,
      email: Value(email),
      phone: Value(phone),
      address: Value(address),
      nic: Value(nic),
      creditEnabled: Value(creditEnabled),
      creditLimit: Value(creditLimit),
      creditBalance: const Value(0),
      notes: Value(notes),
      isActive: const Value(true),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    return (await getCustomerById(id))!;
  }

  // Update customer
  Future<bool> updateCustomer({
    required String id,
    String? code,
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
    final now = DateTime.now();

    return await (update(customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        code: code != null ? Value(code) : const Value.absent(),
        name: name != null ? Value(name) : const Value.absent(),
        email: Value(email),
        phone: Value(phone),
        address: Value(address),
        nic: Value(nic),
        creditEnabled: creditEnabled != null ? Value(creditEnabled) : const Value.absent(),
        creditLimit: creditLimit != null ? Value(creditLimit) : const Value.absent(),
        notes: Value(notes),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    ) > 0;
  }

  // Update credit balance (called from sales/payments)
  Future<void> updateCreditBalance(String customerId, double newBalance) async {
    final now = DateTime.now();
    await (update(customers)..where((t) => t.id.equals(customerId))).write(
      CustomersCompanion(
        creditBalance: Value(newBalance),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Add to credit balance
  Future<void> addToCreditBalance(String customerId, double amount) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      await updateCreditBalance(customerId, customer.creditBalance + amount);
    }
  }

  // Subtract from credit balance
  Future<void> subtractFromCreditBalance(String customerId, double amount) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      final newBalance = customer.creditBalance - amount;
      await updateCreditBalance(customerId, newBalance < 0 ? 0 : newBalance);
    }
  }

  // Soft delete customer
  Future<bool> deleteCustomer(String id) async {
    return await updateCustomer(id: id, isActive: false);
  }

  // Search customers
  Future<List<Customer>> searchCustomers(String query) {
    final searchTerm = '%$query%';
    return (select(customers)
          ..where((t) =>
              (t.name.like(searchTerm) |
                  t.code.like(searchTerm) |
                  t.phone.like(searchTerm) |
                  t.email.like(searchTerm)) &
              t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Check if code exists
  Future<bool> isCodeExists(String code, {String? excludeId}) async {
    final query = select(customers)..where((t) => t.code.equals(code));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // Check available credit
  Future<double> getAvailableCredit(String customerId) async {
    final customer = await getCustomerById(customerId);
    if (customer == null || !customer.creditEnabled) return 0;
    return customer.creditLimit - customer.creditBalance;
  }
}
