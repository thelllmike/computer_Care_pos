import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../tables/suppliers_table.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase> with _$SupplierDaoMixin {
  SupplierDao(super.db);

  static const _uuid = Uuid();

  // Get all active suppliers
  Future<List<Supplier>> getAllSuppliers() {
    return (select(suppliers)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Watch all active suppliers
  Stream<List<Supplier>> watchAllSuppliers() {
    return (select(suppliers)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  // Get supplier by ID
  Future<Supplier?> getSupplierById(String id) {
    return (select(suppliers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get supplier by code
  Future<Supplier?> getSupplierByCode(String code) {
    return (select(suppliers)..where((t) => t.code.equals(code))).getSingleOrNull();
  }

  // Insert supplier
  Future<Supplier> insertSupplier({
    required String code,
    required String name,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? taxId,
    int paymentTermDays = 30,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(suppliers).insert(SuppliersCompanion.insert(
      id: id,
      code: code,
      name: name,
      contactPerson: Value(contactPerson),
      email: Value(email),
      phone: Value(phone),
      address: Value(address),
      taxId: Value(taxId),
      paymentTermDays: Value(paymentTermDays),
      notes: Value(notes),
      isActive: const Value(true),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    return (await getSupplierById(id))!;
  }

  // Update supplier
  Future<bool> updateSupplier({
    required String id,
    String? code,
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
    final now = DateTime.now();

    return await (update(suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        code: code != null ? Value(code) : const Value.absent(),
        name: name != null ? Value(name) : const Value.absent(),
        contactPerson: Value(contactPerson),
        email: Value(email),
        phone: Value(phone),
        address: Value(address),
        taxId: Value(taxId),
        paymentTermDays: paymentTermDays != null ? Value(paymentTermDays) : const Value.absent(),
        notes: Value(notes),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    ) > 0;
  }

  // Soft delete supplier
  Future<bool> deleteSupplier(String id) async {
    return await updateSupplier(id: id, isActive: false);
  }

  // Search suppliers
  Future<List<Supplier>> searchSuppliers(String query) {
    final searchTerm = '%$query%';
    return (select(suppliers)
          ..where((t) =>
              (t.name.like(searchTerm) |
                  t.code.like(searchTerm) |
                  t.contactPerson.like(searchTerm) |
                  t.phone.like(searchTerm)) &
              t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Check if code exists
  Future<bool> isCodeExists(String code, {String? excludeId}) async {
    final query = select(suppliers)..where((t) => t.code.equals(code));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    final result = await query.getSingleOrNull();
    return result != null;
  }
}
