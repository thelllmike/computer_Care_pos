import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/order_status.dart';
import '../database/app_database.dart';
import '../tables/purchase_orders_table.dart';
import '../tables/products_table.dart';
import '../tables/suppliers_table.dart';

part 'purchase_order_dao.g.dart';

@DriftAccessor(tables: [PurchaseOrders, PurchaseOrderItems, Products, Suppliers])
class PurchaseOrderDao extends DatabaseAccessor<AppDatabase> with _$PurchaseOrderDaoMixin {
  PurchaseOrderDao(super.db);

  static const _uuid = Uuid();

  // ==================== Purchase Order Operations ====================

  // Get all purchase orders
  Future<List<PurchaseOrderWithSupplier>> getAllPurchaseOrders() async {
    final query = select(purchaseOrders).join([
      leftOuterJoin(suppliers, suppliers.id.equalsExp(purchaseOrders.supplierId)),
    ])
      ..orderBy([OrderingTerm.desc(purchaseOrders.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return PurchaseOrderWithSupplier(
        purchaseOrder: row.readTable(purchaseOrders),
        supplier: row.readTableOrNull(suppliers),
      );
    }).toList();
  }

  // Get purchase orders by status
  Future<List<PurchaseOrderWithSupplier>> getPurchaseOrdersByStatus(OrderStatus status) async {
    final query = select(purchaseOrders).join([
      leftOuterJoin(suppliers, suppliers.id.equalsExp(purchaseOrders.supplierId)),
    ])
      ..where(purchaseOrders.status.equals(status.code))
      ..orderBy([OrderingTerm.desc(purchaseOrders.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return PurchaseOrderWithSupplier(
        purchaseOrder: row.readTable(purchaseOrders),
        supplier: row.readTableOrNull(suppliers),
      );
    }).toList();
  }

  // Get pending purchase orders for a supplier
  Future<List<PurchaseOrder>> getPendingOrdersBySupplier(String supplierId) {
    return (select(purchaseOrders)
          ..where((t) => t.supplierId.equals(supplierId) &
              (t.status.equals(OrderStatus.draft.code) |
               t.status.equals(OrderStatus.confirmed.code) |
               t.status.equals(OrderStatus.partiallyReceived.code)))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // Get purchase order by ID
  Future<PurchaseOrder?> getPurchaseOrderById(String id) {
    return (select(purchaseOrders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get purchase order with items
  Future<PurchaseOrderDetail?> getPurchaseOrderDetail(String id) async {
    final po = await getPurchaseOrderById(id);
    if (po == null) return null;

    final supplier = po.supplierId != null
        ? await (select(suppliers)..where((t) => t.id.equals(po.supplierId!))).getSingleOrNull()
        : null;

    final items = await getPurchaseOrderItems(id);

    return PurchaseOrderDetail(
      purchaseOrder: po,
      supplier: supplier,
      items: items,
    );
  }

  // Watch purchase order by ID
  Stream<PurchaseOrder?> watchPurchaseOrderById(String id) {
    return (select(purchaseOrders)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  // Create purchase order
  Future<PurchaseOrder> createPurchaseOrder({
    required String supplierId,
    String? notes,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final orderNumber = await db.getNextSequenceNumber('PURCHASE_ORDER');

    await into(purchaseOrders).insert(PurchaseOrdersCompanion.insert(
      id: id,
      orderNumber: orderNumber,
      supplierId: supplierId,
      orderDate: now,
      status: Value(OrderStatus.draft.code),
      totalAmount: const Value(0),
      notes: Value(notes),
      createdBy: Value(createdBy),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    return (await getPurchaseOrderById(id))!;
  }

  // Update purchase order
  Future<void> updatePurchaseOrder({
    required String id,
    String? supplierId,
    String? notes,
  }) async {
    final now = DateTime.now();
    await (update(purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        supplierId: supplierId != null ? Value(supplierId) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Update purchase order status
  Future<void> updatePurchaseOrderStatus(String id, OrderStatus status) async {
    final now = DateTime.now();
    await (update(purchaseOrders)..where((t) => t.id.equals(id))).write(
      PurchaseOrdersCompanion(
        status: Value(status.code),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Delete purchase order (only drafts)
  Future<bool> deletePurchaseOrder(String id) async {
    final po = await getPurchaseOrderById(id);
    if (po == null || po.status != OrderStatus.draft.code) {
      return false;
    }

    // Delete items first
    await (delete(purchaseOrderItems)..where((t) => t.purchaseOrderId.equals(id))).go();
    // Delete PO
    await (delete(purchaseOrders)..where((t) => t.id.equals(id))).go();
    return true;
  }

  // ==================== Purchase Order Items ====================

  // Get items for a purchase order
  Future<List<PurchaseOrderItemWithProduct>> getPurchaseOrderItems(String purchaseOrderId) async {
    final query = select(purchaseOrderItems).join([
      innerJoin(products, products.id.equalsExp(purchaseOrderItems.productId)),
    ])
      ..where(purchaseOrderItems.purchaseOrderId.equals(purchaseOrderId))
      ..orderBy([OrderingTerm.asc(purchaseOrderItems.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return PurchaseOrderItemWithProduct(
        item: row.readTable(purchaseOrderItems),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Add item to purchase order
  Future<PurchaseOrderItem> addPurchaseOrderItem({
    required String purchaseOrderId,
    required String productId,
    required int quantity,
    required double unitCost,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final totalCost = quantity * unitCost;
    await into(purchaseOrderItems).insert(PurchaseOrderItemsCompanion.insert(
      id: id,
      purchaseOrderId: purchaseOrderId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      totalCost: totalCost,
      receivedQuantity: const Value(0),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Update PO total
    await _updatePurchaseOrderTotal(purchaseOrderId);

    return (await (select(purchaseOrderItems)..where((t) => t.id.equals(id))).getSingle());
  }

  // Update purchase order item
  Future<void> updatePurchaseOrderItem({
    required String id,
    int? quantity,
    double? unitCost,
  }) async {
    final now = DateTime.now();
    final item = await (select(purchaseOrderItems)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) return;

    await (update(purchaseOrderItems)..where((t) => t.id.equals(id))).write(
      PurchaseOrderItemsCompanion(
        quantity: quantity != null ? Value(quantity) : const Value.absent(),
        unitCost: unitCost != null ? Value(unitCost) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );

    await _updatePurchaseOrderTotal(item.purchaseOrderId);
  }

  // Update received quantity
  Future<void> updateReceivedQuantity(String itemId, int receivedQuantity) async {
    final now = DateTime.now();
    await (update(purchaseOrderItems)..where((t) => t.id.equals(itemId))).write(
      PurchaseOrderItemsCompanion(
        receivedQuantity: Value(receivedQuantity),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Delete purchase order item
  Future<void> deletePurchaseOrderItem(String id) async {
    final item = await (select(purchaseOrderItems)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) return;

    await (delete(purchaseOrderItems)..where((t) => t.id.equals(id))).go();
    await _updatePurchaseOrderTotal(item.purchaseOrderId);
  }

  // Update purchase order total amount
  Future<void> _updatePurchaseOrderTotal(String purchaseOrderId) async {
    final items = await (select(purchaseOrderItems)
          ..where((t) => t.purchaseOrderId.equals(purchaseOrderId)))
        .get();

    double total = 0;
    for (final item in items) {
      total += item.quantity * item.unitCost;
    }

    final now = DateTime.now();
    await (update(purchaseOrders)..where((t) => t.id.equals(purchaseOrderId))).write(
      PurchaseOrdersCompanion(
        totalAmount: Value(total),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }
}

// Helper classes
class PurchaseOrderWithSupplier {
  final PurchaseOrder purchaseOrder;
  final Supplier? supplier;

  PurchaseOrderWithSupplier({
    required this.purchaseOrder,
    this.supplier,
  });

  String get orderNumber => purchaseOrder.orderNumber;
  String get status => purchaseOrder.status;
  double get totalAmount => purchaseOrder.totalAmount;
  DateTime get createdAt => purchaseOrder.createdAt;
  String? get supplierName => supplier?.name;
}

class PurchaseOrderItemWithProduct {
  final PurchaseOrderItem item;
  final Product product;

  PurchaseOrderItemWithProduct({
    required this.item,
    required this.product,
  });

  String get productName => product.name;
  String get productCode => product.code;
  int get quantity => item.quantity;
  double get unitCost => item.unitCost;
  double get totalCost => item.quantity * item.unitCost;
  int get receivedQuantity => item.receivedQuantity;
  int get pendingQuantity => item.quantity - item.receivedQuantity;
}

class PurchaseOrderDetail {
  final PurchaseOrder purchaseOrder;
  final Supplier? supplier;
  final List<PurchaseOrderItemWithProduct> items;

  PurchaseOrderDetail({
    required this.purchaseOrder,
    this.supplier,
    required this.items,
  });

  double get totalAmount => items.fold(0, (sum, item) => sum + item.totalCost);
  int get totalItems => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  int get totalReceived => items.fold(0, (sum, item) => sum + item.receivedQuantity);
  bool get isFullyReceived => totalReceived >= totalQuantity;
}
