import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/serial_status.dart';
import '../database/app_database.dart';
import '../tables/inventory_table.dart';
import '../tables/serial_numbers_table.dart';
import '../tables/products_table.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [Inventory, SerialNumbers, SerialNumberHistory, Products])
class InventoryDao extends DatabaseAccessor<AppDatabase> with _$InventoryDaoMixin {
  InventoryDao(super.db);

  static const _uuid = Uuid();

  // ==================== Inventory Operations ====================

  // Get inventory for a product
  Future<InventoryData?> getInventoryByProductId(String productId) {
    return (select(inventory)..where((t) => t.productId.equals(productId)))
        .getSingleOrNull();
  }

  // Watch inventory for a product
  Stream<InventoryData?> watchInventoryByProductId(String productId) {
    return (select(inventory)..where((t) => t.productId.equals(productId)))
        .watchSingleOrNull();
  }

  // Get all inventory with product details
  Future<List<InventoryWithProduct>> getAllInventoryWithProducts() async {
    final query = select(inventory).join([
      innerJoin(products, products.id.equalsExp(inventory.productId)),
    ])
      ..where(products.isActive.equals(true))
      ..orderBy([OrderingTerm.asc(products.name)]);

    final results = await query.get();
    return results.map((row) {
      return InventoryWithProduct(
        inventory: row.readTable(inventory),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Get low stock items
  Future<List<InventoryWithProduct>> getLowStockItems() async {
    final query = select(inventory).join([
      innerJoin(products, products.id.equalsExp(inventory.productId)),
    ])
      ..where(products.isActive.equals(true) &
          inventory.quantityOnHand.isSmallerOrEqual(products.reorderLevel))
      ..orderBy([OrderingTerm.asc(inventory.quantityOnHand)]);

    final results = await query.get();
    return results.map((row) {
      return InventoryWithProduct(
        inventory: row.readTable(inventory),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Update inventory quantities (used by GRN, Sales, Adjustments)
  Future<void> updateInventory({
    required String productId,
    required int quantityChange,
    required double costChange,
  }) async {
    final now = DateTime.now();
    final current = await getInventoryByProductId(productId);

    if (current != null) {
      await (update(inventory)..where((t) => t.productId.equals(productId))).write(
        InventoryCompanion(
          quantityOnHand: Value(current.quantityOnHand + quantityChange),
          totalCost: Value(current.totalCost + costChange),
          lastStockDate: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );
    }
  }

  // Set inventory directly (for adjustments)
  Future<void> setInventory({
    required String productId,
    required int quantity,
    required double totalCost,
  }) async {
    final now = DateTime.now();
    await (update(inventory)..where((t) => t.productId.equals(productId))).write(
      InventoryCompanion(
        quantityOnHand: Value(quantity),
        totalCost: Value(totalCost),
        lastStockDate: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // ==================== Serial Number Operations ====================

  // Get serial number by ID
  Future<SerialNumber?> getSerialNumberById(String id) {
    return (select(serialNumbers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get serial number by serial string
  Future<SerialNumber?> getSerialNumberBySerial(String serial) {
    return (select(serialNumbers)..where((t) => t.serialNumber.equals(serial)))
        .getSingleOrNull();
  }

  // Get available serial numbers for a product
  Future<List<SerialNumber>> getAvailableSerialNumbers(String productId) {
    return (select(serialNumbers)
          ..where((t) =>
              t.productId.equals(productId) &
              t.status.equals(SerialStatus.inStock.code))
          ..orderBy([(t) => OrderingTerm.asc(t.serialNumber)]))
        .get();
  }

  // Watch available serial numbers for a product
  Stream<List<SerialNumber>> watchAvailableSerialNumbers(String productId) {
    return (select(serialNumbers)
          ..where((t) =>
              t.productId.equals(productId) &
              t.status.equals(SerialStatus.inStock.code))
          ..orderBy([(t) => OrderingTerm.asc(t.serialNumber)]))
        .watch();
  }

  // Get all serial numbers for a product
  Future<List<SerialNumber>> getSerialNumbersByProduct(String productId) {
    return (select(serialNumbers)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // Get serial numbers by status
  Future<List<SerialNumber>> getSerialNumbersByStatus(SerialStatus status) {
    return (select(serialNumbers)
          ..where((t) => t.status.equals(status.code))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // Get serial numbers for a customer
  Future<List<SerialNumber>> getSerialNumbersByCustomer(String customerId) {
    return (select(serialNumbers)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // Insert serial number (used by GRN)
  Future<SerialNumber> insertSerialNumber({
    required String serialNumber,
    required String productId,
    required double unitCost,
    String? grnId,
    String? grnItemId,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(serialNumbers).insert(SerialNumbersCompanion.insert(
      id: id,
      serialNumber: serialNumber,
      productId: productId,
      status: Value(SerialStatus.inStock.code),
      unitCost: Value(unitCost),
      grnId: Value(grnId),
      grnItemId: Value(grnItemId),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Add history entry
    await addSerialHistory(
      serialNumberId: id,
      fromStatus: null,
      toStatus: SerialStatus.inStock,
      referenceType: 'GRN',
      referenceId: grnId,
      createdBy: createdBy,
    );

    return (await getSerialNumberById(id))!;
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
    final now = DateTime.now();
    final current = await getSerialNumberById(serialId);

    if (current != null) {
      final oldStatus = SerialStatusExtension.fromString(current.status);

      await (update(serialNumbers)..where((t) => t.id.equals(serialId))).write(
        SerialNumbersCompanion(
          status: Value(newStatus.code),
          saleId: Value(saleId),
          customerId: Value(customerId),
          warrantyStartDate: Value(warrantyStartDate),
          warrantyEndDate: Value(warrantyEndDate),
          notes: Value(notes),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );

      // Add history entry
      await addSerialHistory(
        serialNumberId: serialId,
        fromStatus: oldStatus,
        toStatus: newStatus,
        referenceType: referenceType,
        referenceId: referenceId,
        notes: notes,
        createdBy: changedBy,
      );
    }
  }

  // Add serial number history entry
  Future<void> addSerialHistory({
    required String serialNumberId,
    required SerialStatus? fromStatus,
    required SerialStatus toStatus,
    String? referenceType,
    String? referenceId,
    String? notes,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(serialNumberHistory).insert(SerialNumberHistoryCompanion.insert(
      id: id,
      serialNumberId: serialNumberId,
      fromStatus: fromStatus?.code ?? '',
      toStatus: toStatus.code,
      referenceType: Value(referenceType),
      referenceId: Value(referenceId),
      notes: Value(notes),
      createdBy: Value(createdBy),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));
  }

  // Get serial number history
  Future<List<SerialNumberHistoryData>> getSerialHistory(String serialNumberId) {
    return (select(serialNumberHistory)
          ..where((t) => t.serialNumberId.equals(serialNumberId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // Search serial numbers
  Future<List<SerialNumber>> searchSerialNumbers(String query) {
    final searchTerm = '%$query%';
    return (select(serialNumbers)
          ..where((t) => t.serialNumber.like(searchTerm))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // Check if serial number exists
  Future<bool> isSerialExists(String serial) async {
    final result = await getSerialNumberBySerial(serial);
    return result != null;
  }
}

// Helper class for inventory with product details
class InventoryWithProduct {
  final InventoryData inventory;
  final Product product;

  InventoryWithProduct({
    required this.inventory,
    required this.product,
  });

  int get quantityOnHand => inventory.quantityOnHand;
  double get totalCost => inventory.totalCost;
  double get wac => quantityOnHand > 0 ? totalCost / quantityOnHand : 0;
  bool get isLowStock => quantityOnHand <= product.reorderLevel;
  int get availableQuantity => inventory.quantityOnHand - inventory.reservedQuantity;
}
