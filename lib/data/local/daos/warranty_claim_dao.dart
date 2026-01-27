import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/serial_status.dart';
import '../database/app_database.dart';
import '../tables/warranty_claims_table.dart';
import '../tables/serial_numbers_table.dart';
import '../tables/products_table.dart';
import '../tables/suppliers_table.dart';

part 'warranty_claim_dao.g.dart';

@DriftAccessor(
    tables: [WarrantyClaims, WarrantyClaimHistory, SerialNumbers, Products, Suppliers])
class WarrantyClaimDao extends DatabaseAccessor<AppDatabase>
    with _$WarrantyClaimDaoMixin {
  WarrantyClaimDao(super.db);

  static const _uuid = Uuid();

  // Get all warranty claims with serial, product, supplier info
  Future<List<WarrantyClaimWithDetails>> getAllWarrantyClaims() async {
    final query = select(warrantyClaims).join([
      innerJoin(
          serialNumbers, serialNumbers.id.equalsExp(warrantyClaims.serialNumberId)),
      innerJoin(products, products.id.equalsExp(serialNumbers.productId)),
      innerJoin(suppliers, suppliers.id.equalsExp(warrantyClaims.supplierId)),
    ])
      ..orderBy([OrderingTerm.desc(warrantyClaims.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return WarrantyClaimWithDetails(
        claim: row.readTable(warrantyClaims),
        serialNumber: row.readTable(serialNumbers),
        product: row.readTable(products),
        supplier: row.readTable(suppliers),
      );
    }).toList();
  }

  // Get active warranty claims (not resolved or rejected)
  Future<List<WarrantyClaimWithDetails>> getActiveWarrantyClaims() async {
    final query = select(warrantyClaims).join([
      innerJoin(
          serialNumbers, serialNumbers.id.equalsExp(warrantyClaims.serialNumberId)),
      innerJoin(products, products.id.equalsExp(serialNumbers.productId)),
      innerJoin(suppliers, suppliers.id.equalsExp(warrantyClaims.supplierId)),
    ])
      ..where(warrantyClaims.status.isNotIn(
          [WarrantyClaimStatus.resolved.code, WarrantyClaimStatus.rejected.code]))
      ..orderBy([OrderingTerm.desc(warrantyClaims.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return WarrantyClaimWithDetails(
        claim: row.readTable(warrantyClaims),
        serialNumber: row.readTable(serialNumbers),
        product: row.readTable(products),
        supplier: row.readTable(suppliers),
      );
    }).toList();
  }

  // Get warranty claims by status
  Future<List<WarrantyClaimWithDetails>> getWarrantyClaimsByStatus(
      WarrantyClaimStatus status) async {
    final query = select(warrantyClaims).join([
      innerJoin(
          serialNumbers, serialNumbers.id.equalsExp(warrantyClaims.serialNumberId)),
      innerJoin(products, products.id.equalsExp(serialNumbers.productId)),
      innerJoin(suppliers, suppliers.id.equalsExp(warrantyClaims.supplierId)),
    ])
      ..where(warrantyClaims.status.equals(status.code))
      ..orderBy([OrderingTerm.desc(warrantyClaims.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return WarrantyClaimWithDetails(
        claim: row.readTable(warrantyClaims),
        serialNumber: row.readTable(serialNumbers),
        product: row.readTable(products),
        supplier: row.readTable(suppliers),
      );
    }).toList();
  }

  // Get warranty claim by ID
  Future<WarrantyClaim?> getWarrantyClaimById(String id) {
    return (select(warrantyClaims)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // Get warranty claim detail
  Future<WarrantyClaimWithDetails?> getWarrantyClaimDetail(String id) async {
    final query = select(warrantyClaims).join([
      innerJoin(
          serialNumbers, serialNumbers.id.equalsExp(warrantyClaims.serialNumberId)),
      innerJoin(products, products.id.equalsExp(serialNumbers.productId)),
      innerJoin(suppliers, suppliers.id.equalsExp(warrantyClaims.supplierId)),
    ])
      ..where(warrantyClaims.id.equals(id));

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return WarrantyClaimWithDetails(
      claim: result.readTable(warrantyClaims),
      serialNumber: result.readTable(serialNumbers),
      product: result.readTable(products),
      supplier: result.readTable(suppliers),
    );
  }

  // Create warranty claim - generates number, updates serial to DEFECTIVE
  Future<WarrantyClaim> createWarrantyClaim({
    required String serialNumberId,
    required String supplierId,
    required String claimReason,
    String? notes,
    String? createdBy,
  }) async {
    return transaction(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final claimNumber = await db.getNextSequenceNumber('WARRANTY_CLAIM');

      // Insert warranty claim
      await into(warrantyClaims).insert(WarrantyClaimsCompanion.insert(
        id: id,
        claimNumber: claimNumber,
        serialNumberId: serialNumberId,
        supplierId: supplierId,
        claimReason: claimReason,
        status: const Value('PENDING'),
        createdBy: Value(createdBy),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ));

      // Add history entry
      await _addClaimHistory(
        claimId: id,
        fromStatus: null,
        toStatus: WarrantyClaimStatus.pending,
        notes: 'Warranty claim created',
        changedBy: createdBy,
      );

      // Update serial status to DEFECTIVE
      await db.inventoryDao.updateSerialStatus(
        serialId: serialNumberId,
        newStatus: SerialStatus.defective,
        referenceType: 'WARRANTY_CLAIM',
        referenceId: id,
        notes: 'Warranty claim: $claimReason',
        changedBy: createdBy,
      );

      return (await getWarrantyClaimById(id))!;
    });
  }

  // Update warranty claim status with validation
  Future<bool> updateWarrantyClaimStatus({
    required String id,
    required WarrantyClaimStatus newStatus,
    DateTime? dateSentToSupplier,
    DateTime? expectedReturnDate,
    DateTime? actualReturnDate,
    String? supplierResponse,
    String? resolutionNotes,
    String? changedBy,
  }) async {
    final claim = await getWarrantyClaimById(id);
    if (claim == null) return false;

    final currentStatus = WarrantyClaimStatus.fromCode(claim.status);

    // Validate status transition
    if (!currentStatus.canTransitionTo(newStatus)) {
      throw Exception(
          'Invalid status transition from ${currentStatus.displayName} to ${newStatus.displayName}');
    }

    final now = DateTime.now();

    await (update(warrantyClaims)..where((t) => t.id.equals(id))).write(
      WarrantyClaimsCompanion(
        status: Value(newStatus.code),
        dateSentToSupplier: dateSentToSupplier != null
            ? Value(dateSentToSupplier)
            : const Value.absent(),
        expectedReturnDate: expectedReturnDate != null
            ? Value(expectedReturnDate)
            : const Value.absent(),
        actualReturnDate: actualReturnDate != null
            ? Value(actualReturnDate)
            : const Value.absent(),
        supplierResponse: supplierResponse != null
            ? Value(supplierResponse)
            : const Value.absent(),
        resolutionNotes: resolutionNotes != null
            ? Value(resolutionNotes)
            : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );

    // Add history entry
    await _addClaimHistory(
      claimId: id,
      fromStatus: currentStatus,
      toStatus: newStatus,
      notes: resolutionNotes ?? supplierResponse,
      changedBy: changedBy,
    );

    // Handle serial status based on new warranty claim status
    if (newStatus == WarrantyClaimStatus.resolved) {
      // If resolved, serial can go back to IN_STOCK (replaced/repaired)
      await db.inventoryDao.updateSerialStatus(
        serialId: claim.serialNumberId,
        newStatus: SerialStatus.inStock,
        referenceType: 'WARRANTY_CLAIM',
        referenceId: id,
        notes: 'Warranty resolved: $resolutionNotes',
        changedBy: changedBy,
      );
    } else if (newStatus == WarrantyClaimStatus.rejected) {
      // If rejected, serial stays DEFECTIVE or goes to DISPOSED
      await db.inventoryDao.updateSerialStatus(
        serialId: claim.serialNumberId,
        newStatus: SerialStatus.disposed,
        referenceType: 'WARRANTY_CLAIM',
        referenceId: id,
        notes: 'Warranty rejected: $resolutionNotes',
        changedBy: changedBy,
      );
    }

    return true;
  }

  // Add claim history entry
  Future<void> _addClaimHistory({
    required String claimId,
    required WarrantyClaimStatus? fromStatus,
    required WarrantyClaimStatus toStatus,
    String? notes,
    String? changedBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(warrantyClaimHistory).insert(WarrantyClaimHistoryCompanion.insert(
      id: id,
      warrantyClaimId: claimId,
      fromStatus: Value(fromStatus?.code),
      toStatus: toStatus.code,
      notes: Value(notes),
      changedBy: Value(changedBy),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));
  }

  // Get claim history
  Future<List<WarrantyClaimHistoryData>> getClaimHistory(String claimId) {
    return (select(warrantyClaimHistory)
          ..where((t) => t.warrantyClaimId.equals(claimId))
          ..orderBy([(t) => OrderingTerm.desc(t.changedAt)]))
        .get();
  }

  // Get warranty summary - count by status
  Future<WarrantySummary> getWarrantySummary() async {
    final allClaims = await (select(warrantyClaims)).get();

    final Map<String, int> statusCounts = {};
    for (final claim in allClaims) {
      statusCounts[claim.status] = (statusCounts[claim.status] ?? 0) + 1;
    }

    return WarrantySummary(
      totalClaims: allClaims.length,
      statusCounts: statusCounts,
    );
  }

  // Get sold items under warranty (for creating new claims)
  Future<List<SerialNumberWithProduct>> getSoldItemsUnderWarranty() async {
    final now = DateTime.now();

    final query = select(serialNumbers).join([
      innerJoin(products, products.id.equalsExp(serialNumbers.productId)),
    ])
      ..where(serialNumbers.status.equals(SerialStatus.sold.code) &
          serialNumbers.warrantyEndDate.isBiggerOrEqualValue(now))
      ..orderBy([OrderingTerm.desc(serialNumbers.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return SerialNumberWithProduct(
        serialNumber: row.readTable(serialNumbers),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Search serial numbers by serial string (for creating claims)
  Future<List<SerialNumberWithProduct>> searchSerialsForWarranty(
      String query) async {
    final now = DateTime.now();
    final searchTerm = '%$query%';

    final queryBuilder = select(serialNumbers).join([
      innerJoin(products, products.id.equalsExp(serialNumbers.productId)),
    ])
      ..where(serialNumbers.serialNumber.like(searchTerm) &
          serialNumbers.status.equals(SerialStatus.sold.code) &
          serialNumbers.warrantyEndDate.isBiggerOrEqualValue(now))
      ..orderBy([OrderingTerm.desc(serialNumbers.createdAt)]);

    final results = await queryBuilder.get();
    return results.map((row) {
      return SerialNumberWithProduct(
        serialNumber: row.readTable(serialNumbers),
        product: row.readTable(products),
      );
    }).toList();
  }
}

// Helper classes
class WarrantyClaimWithDetails {
  final WarrantyClaim claim;
  final SerialNumber serialNumber;
  final Product product;
  final Supplier supplier;

  WarrantyClaimWithDetails({
    required this.claim,
    required this.serialNumber,
    required this.product,
    required this.supplier,
  });

  String get claimNumber => claim.claimNumber;
  String get serialNumberString => serialNumber.serialNumber;
  String get productName => product.name;
  String get productCode => product.code;
  String get supplierName => supplier.name;
  String get claimReason => claim.claimReason;
  WarrantyClaimStatus get status => WarrantyClaimStatus.fromCode(claim.status);
  String get statusDisplayName => status.displayName;
  DateTime get createdAt => claim.createdAt;
  DateTime? get dateSentToSupplier => claim.dateSentToSupplier;
  DateTime? get expectedReturnDate => claim.expectedReturnDate;
  DateTime? get actualReturnDate => claim.actualReturnDate;
  String? get supplierResponse => claim.supplierResponse;
  String? get resolutionNotes => claim.resolutionNotes;

  int get daysPending {
    if (status == WarrantyClaimStatus.resolved ||
        status == WarrantyClaimStatus.rejected) {
      return 0;
    }
    return DateTime.now().difference(claim.createdAt).inDays;
  }
}

class WarrantySummary {
  final int totalClaims;
  final Map<String, int> statusCounts;

  WarrantySummary({
    required this.totalClaims,
    required this.statusCounts,
  });

  int getCountByStatus(WarrantyClaimStatus status) =>
      statusCounts[status.code] ?? 0;

  int get pendingCount => getCountByStatus(WarrantyClaimStatus.pending);
  int get sentToSupplierCount =>
      getCountByStatus(WarrantyClaimStatus.sentToSupplier);
  int get inRepairCount => getCountByStatus(WarrantyClaimStatus.inRepair);
  int get returnedCount => getCountByStatus(WarrantyClaimStatus.returned);
  int get resolvedCount => getCountByStatus(WarrantyClaimStatus.resolved);
  int get rejectedCount => getCountByStatus(WarrantyClaimStatus.rejected);
  int get activeCount => totalClaims - resolvedCount - rejectedCount;
}

class SerialNumberWithProduct {
  final SerialNumber serialNumber;
  final Product product;

  SerialNumberWithProduct({
    required this.serialNumber,
    required this.product,
  });

  String get serialNumberString => serialNumber.serialNumber;
  String get productName => product.name;
  String get productCode => product.code;
  DateTime? get warrantyEndDate => serialNumber.warrantyEndDate;
  bool get isUnderWarranty =>
      warrantyEndDate != null && warrantyEndDate!.isAfter(DateTime.now());
}
