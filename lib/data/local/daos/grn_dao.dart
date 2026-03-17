import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/serial_status.dart';
import '../../../domain/services/costing_service.dart';
import '../database/app_database.dart';
import '../tables/grn_table.dart';
import '../tables/products_table.dart';
import '../tables/suppliers_table.dart';
import '../tables/inventory_table.dart';
import '../tables/serial_numbers_table.dart';
import '../tables/purchase_orders_table.dart';

part 'grn_dao.g.dart';

@DriftAccessor(tables: [
  Grn, GrnItems, GrnSerials,
  Products, Suppliers, Inventory, SerialNumbers,
  PurchaseOrders, PurchaseOrderItems
])
class GrnDao extends DatabaseAccessor<AppDatabase> with _$GrnDaoMixin {
  GrnDao(super.db);

  static const _uuid = Uuid();

  // ==================== GRN Operations ====================

  // Get all GRNs
  Future<List<GrnWithSupplier>> getAllGrns() async {
    final query = select(grn).join([
      leftOuterJoin(suppliers, suppliers.id.equalsExp(grn.supplierId)),
    ])
      ..orderBy([OrderingTerm.desc(grn.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return GrnWithSupplier(
        grn: row.readTable(grn),
        supplier: row.readTableOrNull(suppliers),
      );
    }).toList();
  }

  // Get GRN by ID
  Future<GrnData?> getGrnById(String id) {
    return (select(grn)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get GRN detail with items
  Future<GrnDetail?> getGrnDetail(String id) async {
    final grnData = await getGrnById(id);
    if (grnData == null) return null;

    final supplier = await (select(suppliers)..where((t) => t.id.equals(grnData.supplierId))).getSingleOrNull();

    final items = await getGrnItems(id);

    return GrnDetail(
      grn: grnData,
      supplier: supplier,
      items: items,
    );
  }

  // Watch GRN by ID
  Stream<GrnData?> watchGrnById(String id) {
    return (select(grn)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  // Create GRN
  Future<GrnData> createGrn({
    required String supplierId,
    String? purchaseOrderId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? notes,
    String? receivedBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // Retry up to 5 times in case of duplicate GRN number
    for (int attempt = 0; attempt < 5; attempt++) {
      final grnNumber = await db.getNextSequenceNumber('GRN');

      try {
        await into(grn).insert(GrnCompanion.insert(
          id: id,
          grnNumber: grnNumber,
          supplierId: supplierId,
          receivedDate: now,
          purchaseOrderId: Value(purchaseOrderId),
          invoiceNumber: Value(invoiceNumber),
          invoiceDate: Value(invoiceDate),
          totalAmount: const Value(0),
          notes: Value(notes),
          receivedBy: Value(receivedBy),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ));

        return (await getGrnById(id))!;
      } catch (e) {
        // If it's a UNIQUE constraint error on grn_number, retry with next number
        if (e.toString().contains('UNIQUE') && e.toString().contains('grn_number')) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Failed to create GRN after 5 attempts. Please try again.');
  }

  // Update GRN
  Future<void> updateGrn({
    required String id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? notes,
  }) async {
    final now = DateTime.now();
    await (update(grn)..where((t) => t.id.equals(id))).write(
      GrnCompanion(
        invoiceNumber: invoiceNumber != null ? Value(invoiceNumber) : const Value.absent(),
        invoiceDate: invoiceDate != null ? Value(invoiceDate) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // ==================== GRN Items ====================

  // Get GRN items
  Future<List<GrnItemWithProduct>> getGrnItems(String grnId) async {
    final query = select(grnItems).join([
      innerJoin(products, products.id.equalsExp(grnItems.productId)),
    ])
      ..where(grnItems.grnId.equals(grnId))
      ..orderBy([OrderingTerm.asc(grnItems.createdAt)]);

    final results = await query.get();

    final itemsWithSerials = <GrnItemWithProduct>[];
    for (final row in results) {
      final item = row.readTable(grnItems);
      final product = row.readTable(products);
      final serials = await getGrnItemSerials(item.id);

      itemsWithSerials.add(GrnItemWithProduct(
        item: item,
        product: product,
        serials: serials,
      ));
    }

    return itemsWithSerials;
  }

  // Add GRN item (non-serialized product)
  Future<GrnItem> addGrnItem({
    required String grnId,
    required String productId,
    required int quantity,
    required double unitCost,
    String? purchaseOrderItemId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(grnItems).insert(GrnItemsCompanion.insert(
      id: id,
      grnId: grnId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      purchaseOrderItemId: Value(purchaseOrderItemId),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Update GRN total
    await _updateGrnTotal(grnId);

    // Update inventory and WAC
    await _updateInventoryOnReceive(productId, quantity, unitCost);

    // Update PO received quantity if linked
    if (purchaseOrderItemId != null) {
      await _updatePoReceivedQuantity(purchaseOrderItemId, quantity);
    }

    return (await (select(grnItems)..where((t) => t.id.equals(id))).getSingle());
  }

  // Add GRN item with serials (for laptops/serialized products)
  Future<GrnItem> addGrnItemWithSerials({
    required String grnId,
    required String productId,
    required List<String> serialNumbers,
    required double unitCost,
    String? purchaseOrderItemId,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final quantity = serialNumbers.length;

    // Create GRN item
    await into(grnItems).insert(GrnItemsCompanion.insert(
      id: id,
      grnId: grnId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      purchaseOrderItemId: Value(purchaseOrderItemId),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Get GRN for reference
    final grnData = await getGrnById(grnId);

    // Create serial numbers and GRN serials
    for (final serial in serialNumbers) {
      final serialId = _uuid.v4();
      final grnSerialId = _uuid.v4();

      // Create serial number record
      await into(this.serialNumbers).insert(SerialNumbersCompanion.insert(
        id: serialId,
        serialNumber: serial,
        productId: productId,
        status: Value(SerialStatus.inStock.code),
        unitCost: Value(unitCost),
        grnId: Value(grnId),
        grnItemId: Value(id),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ));

      // Link to GRN item
      await into(grnSerials).insert(GrnSerialsCompanion.insert(
        id: grnSerialId,
        grnItemId: id,
        serialNumberId: serialId,
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ));

      // Add serial history
      await db.inventoryDao.addSerialHistory(
        serialNumberId: serialId,
        fromStatus: null,
        toStatus: SerialStatus.inStock,
        referenceType: 'GRN',
        referenceId: grnId,
        notes: 'Received via GRN ${grnData?.grnNumber}',
        createdBy: createdBy,
      );
    }

    // Update GRN total
    await _updateGrnTotal(grnId);

    // Update inventory and WAC
    await _updateInventoryOnReceive(productId, quantity, unitCost);

    // Update PO received quantity if linked
    if (purchaseOrderItemId != null) {
      await _updatePoReceivedQuantity(purchaseOrderItemId, quantity);
    }

    return (await (select(grnItems)..where((t) => t.id.equals(id))).getSingle());
  }

  // Get serials for a GRN item
  Future<List<SerialNumber>> getGrnItemSerials(String grnItemId) async {
    final query = select(grnSerials).join([
      innerJoin(serialNumbers, serialNumbers.id.equalsExp(grnSerials.serialNumberId)),
    ])
      ..where(grnSerials.grnItemId.equals(grnItemId));

    final results = await query.get();
    return results.map((row) => row.readTable(serialNumbers)).toList();
  }

  // Get GRN item by ID
  Future<GrnItem?> getGrnItemById(String id) {
    return (select(grnItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Update GRN item (for non-serialized products only - adjusts inventory)
  Future<bool> updateGrnItem({
    required String itemId,
    int? quantity,
    double? unitCost,
  }) async {
    final item = await getGrnItemById(itemId);
    if (item == null) return false;

    final now = DateTime.now();
    final oldQuantity = item.quantity;
    final oldUnitCost = item.unitCost;
    final newQuantity = quantity ?? oldQuantity;
    final newUnitCost = unitCost ?? oldUnitCost;

    // Check if this is a serialized item (can only update unitCost for serialized)
    final serials = await getGrnItemSerials(itemId);
    if (serials.isNotEmpty && quantity != null && quantity != oldQuantity) {
      throw Exception('Cannot change quantity for serialized items. Remove and re-add instead.');
    }

    // Calculate inventory adjustment
    final quantityDiff = newQuantity - oldQuantity;

    // Update the item
    await (update(grnItems)..where((t) => t.id.equals(itemId))).write(
      GrnItemsCompanion(
        quantity: Value(newQuantity),
        unitCost: Value(newUnitCost),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );

    // Update GRN total
    await _updateGrnTotal(item.grnId);

    // Adjust inventory if quantity changed
    if (quantityDiff != 0) {
      await _adjustInventoryForEdit(item.productId, quantityDiff, newUnitCost);
    } else if (unitCost != null && unitCost != oldUnitCost) {
      // If only cost changed, recalculate WAC
      await _recalculateWacForCostChange(
        item.productId,
        oldQuantity,
        oldUnitCost,
        newUnitCost,
      );
    }

    // Update serial costs if cost changed for serialized items
    if (serials.isNotEmpty && unitCost != null && unitCost != oldUnitCost) {
      for (final serial in serials) {
        await (update(serialNumbers)..where((t) => t.id.equals(serial.id))).write(
          SerialNumbersCompanion(
            unitCost: Value(newUnitCost),
            updatedAt: Value(now),
            syncStatus: const Value('PENDING'),
            localUpdatedAt: Value(now),
          ),
        );
      }
    }

    return true;
  }

  // Delete GRN item (reverses inventory changes)
  Future<bool> deleteGrnItem(String itemId) async {
    final item = await getGrnItemById(itemId);
    if (item == null) return false;

    // Check if this is a serialized item
    final serials = await getGrnItemSerials(itemId);

    // For serialized items, check if any have been sold
    if (serials.isNotEmpty) {
      for (final serial in serials) {
        if (serial.status != SerialStatus.inStock.code) {
          throw Exception('Cannot delete item: Serial ${serial.serialNumber} is no longer in stock (status: ${serial.status})');
        }
      }

      // Delete serial numbers and GRN serials
      for (final serial in serials) {
        // Delete GRN serial link
        await (delete(grnSerials)..where((t) => t.serialNumberId.equals(serial.id))).go();
        // Delete serial number record
        await (delete(serialNumbers)..where((t) => t.id.equals(serial.id))).go();
      }
    }

    // Reverse inventory (subtract quantity)
    await _reverseInventoryOnDelete(item.productId, item.quantity, item.unitCost);

    // Delete the item
    await (delete(grnItems)..where((t) => t.id.equals(itemId))).go();

    // Update GRN total
    await _updateGrnTotal(item.grnId);

    // Reverse PO received quantity if linked
    if (item.purchaseOrderItemId != null) {
      await _reversePoReceivedQuantity(item.purchaseOrderItemId!, item.quantity);
    }

    return true;
  }

  // Helper: Adjust inventory for edit (add/subtract difference)
  Future<void> _adjustInventoryForEdit(String productId, int quantityDiff, double unitCost) async {
    if (quantityDiff == 0) return;

    if (quantityDiff > 0) {
      // Adding more - use normal receive logic
      await _updateInventoryOnReceive(productId, quantityDiff, unitCost);
    } else {
      // Removing some - reverse
      await _reverseInventoryOnDelete(productId, -quantityDiff, unitCost);
    }
  }

  // Helper: Recalculate WAC when only cost changes (not quantity)
  Future<void> _recalculateWacForCostChange(
    String productId,
    int quantity,
    double oldCost,
    double newCost,
  ) async {
    final now = DateTime.now();
    final inv = await (select(inventory)
          ..where((t) => t.productId.equals(productId)))
        .getSingleOrNull();

    if (inv != null && inv.quantityOnHand > 0) {
      // Adjust total cost for the difference
      final costDiff = (newCost - oldCost) * quantity;
      final newTotalCost = inv.totalCost + costDiff;
      final newWac = newTotalCost / inv.quantityOnHand;

      await (update(inventory)..where((t) => t.productId.equals(productId))).write(
        InventoryCompanion(
          totalCost: Value(newTotalCost),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );

      // Update product WAC
      await (update(products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          weightedAvgCost: Value(newWac),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );
    }
  }

  // Helper: Reverse inventory on delete
  Future<void> _reverseInventoryOnDelete(String productId, int quantity, double unitCost) async {
    final now = DateTime.now();
    final inv = await (select(inventory)
          ..where((t) => t.productId.equals(productId)))
        .getSingleOrNull();

    if (inv != null) {
      final newQuantity = inv.quantityOnHand - quantity;
      final costToRemove = quantity * unitCost;
      final newTotalCost = inv.totalCost - costToRemove;

      // Recalculate WAC (if still has quantity)
      double newWac = 0;
      if (newQuantity > 0) {
        newWac = newTotalCost / newQuantity;
      }

      await (update(inventory)..where((t) => t.productId.equals(productId))).write(
        InventoryCompanion(
          quantityOnHand: Value(newQuantity),
          totalCost: Value(newTotalCost),
          lastStockDate: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );

      // Update product WAC
      await (update(products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          weightedAvgCost: Value(newWac),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );
    }
  }

  // Helper: Reverse PO received quantity
  Future<void> _reversePoReceivedQuantity(String poItemId, int quantity) async {
    final now = DateTime.now();
    final poItem = await (select(purchaseOrderItems)..where((t) => t.id.equals(poItemId))).getSingleOrNull();

    if (poItem != null) {
      final newReceived = (poItem.receivedQuantity - quantity).clamp(0, poItem.quantity);

      await (update(purchaseOrderItems)..where((t) => t.id.equals(poItemId))).write(
        PurchaseOrderItemsCompanion(
          receivedQuantity: Value(newReceived),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );

      // Update PO status
      await _updatePoStatus(poItem.purchaseOrderId);
    }
  }

  // Update GRN total
  Future<void> _updateGrnTotal(String grnId) async {
    final items = await (select(grnItems)..where((t) => t.grnId.equals(grnId))).get();

    double total = 0;
    for (final item in items) {
      total += item.quantity * item.unitCost;
    }

    final now = DateTime.now();
    await (update(grn)..where((t) => t.id.equals(grnId))).write(
      GrnCompanion(
        totalAmount: Value(total),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Update inventory on receive (with WAC calculation)
  Future<void> _updateInventoryOnReceive(String productId, int quantity, double unitCost) async {
    final now = DateTime.now();
    final currentInventory = await (select(inventory)
          ..where((t) => t.productId.equals(productId)))
        .getSingleOrNull();

    if (currentInventory != null) {
      // Calculate new WAC
      final newWac = CostingService.calculateWAC(
        existingQuantity: currentInventory.quantityOnHand,
        existingTotalCost: currentInventory.totalCost,
        newQuantity: quantity,
        newUnitCost: unitCost,
      );

      final newTotalCost = (currentInventory.quantityOnHand + quantity) * newWac;

      // Update inventory
      await (update(inventory)..where((t) => t.productId.equals(productId))).write(
        InventoryCompanion(
          quantityOnHand: Value(currentInventory.quantityOnHand + quantity),
          totalCost: Value(newTotalCost),
          lastStockDate: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );

      // Update product WAC
      await (update(products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          weightedAvgCost: Value(newWac),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );
    }
  }

  // Update PO received quantity
  Future<void> _updatePoReceivedQuantity(String poItemId, int receivedQuantity) async {
    final now = DateTime.now();
    final poItem = await (select(purchaseOrderItems)..where((t) => t.id.equals(poItemId))).getSingleOrNull();

    if (poItem != null) {
      await (update(purchaseOrderItems)..where((t) => t.id.equals(poItemId))).write(
        PurchaseOrderItemsCompanion(
          receivedQuantity: Value(poItem.receivedQuantity + receivedQuantity),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );

      // Check if PO is fully/partially received
      await _updatePoStatus(poItem.purchaseOrderId);
    }
  }

  // Update PO status based on received quantities
  Future<void> _updatePoStatus(String poId) async {
    final items = await (select(purchaseOrderItems)
          ..where((t) => t.purchaseOrderId.equals(poId)))
        .get();

    int totalOrdered = 0;
    int totalReceived = 0;
    for (final item in items) {
      totalOrdered += item.quantity;
      totalReceived += item.receivedQuantity;
    }

    String newStatus;
    if (totalReceived == 0) {
      newStatus = 'CONFIRMED';
    } else if (totalReceived >= totalOrdered) {
      newStatus = 'RECEIVED';
    } else {
      newStatus = 'PARTIALLY_RECEIVED';
    }

    final now = DateTime.now();
    await (update(purchaseOrders)..where((t) => t.id.equals(poId))).write(
      PurchaseOrdersCompanion(
        status: Value(newStatus),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Check if serial number already exists
  Future<bool> isSerialNumberExists(String serialNumber) async {
    final existing = await (select(serialNumbers)
          ..where((t) => t.serialNumber.equals(serialNumber)))
        .getSingleOrNull();
    return existing != null;
  }

  // Validate serial numbers (check for duplicates)
  Future<List<String>> validateSerialNumbers(List<String> serials) async {
    final duplicates = <String>[];
    for (final serial in serials) {
      if (await isSerialNumberExists(serial)) {
        duplicates.add(serial);
      }
    }
    return duplicates;
  }
}

// Helper classes
class GrnWithSupplier {
  final GrnData grn;
  final Supplier? supplier;

  GrnWithSupplier({
    required this.grn,
    this.supplier,
  });

  String get grnNumber => grn.grnNumber;
  String? get supplierName => supplier?.name;
  double get totalAmount => grn.totalAmount;
  DateTime get receivedDate => grn.receivedDate;
}

class GrnItemWithProduct {
  final GrnItem item;
  final Product product;
  final List<SerialNumber> serials;

  GrnItemWithProduct({
    required this.item,
    required this.product,
    this.serials = const [],
  });

  String get productName => product.name;
  String get productCode => product.code;
  int get quantity => item.quantity;
  double get unitCost => item.unitCost;
  double get totalCost => item.quantity * item.unitCost;
  bool get hasSerialized => product.requiresSerial;
  List<String> get serialNumberList => serials.map((s) => s.serialNumber).toList();
}

class GrnDetail {
  final GrnData grn;
  final Supplier? supplier;
  final List<GrnItemWithProduct> items;

  GrnDetail({
    required this.grn,
    this.supplier,
    required this.items,
  });

  String get grnNumber => grn.grnNumber;
  String? get supplierName => supplier?.name;
  double get totalAmount => items.fold(0, (sum, item) => sum + item.totalCost);
  int get totalItems => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}
