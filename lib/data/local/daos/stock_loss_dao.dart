import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/serial_status.dart';
import '../database/app_database.dart';
import '../tables/stock_losses_table.dart';
import '../tables/products_table.dart';
import '../tables/serial_numbers_table.dart';
import '../tables/inventory_table.dart';

part 'stock_loss_dao.g.dart';

@DriftAccessor(tables: [StockLosses, Products, SerialNumbers, Inventory])
class StockLossDao extends DatabaseAccessor<AppDatabase>
    with _$StockLossDaoMixin {
  StockLossDao(super.db);

  static const _uuid = Uuid();

  // Get all stock losses with product info
  Future<List<StockLossWithProduct>> getAllStockLosses() async {
    final query = select(stockLosses).join([
      innerJoin(products, products.id.equalsExp(stockLosses.productId)),
    ])
      ..orderBy([OrderingTerm.desc(stockLosses.lossDate)]);

    final results = await query.get();
    return results.map((row) {
      return StockLossWithProduct(
        stockLoss: row.readTable(stockLosses),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Get stock losses by date range
  Future<List<StockLossWithProduct>> getStockLossesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final endOfDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final query = select(stockLosses).join([
      innerJoin(products, products.id.equalsExp(stockLosses.productId)),
    ])
      ..where(stockLosses.lossDate.isBiggerOrEqualValue(startDate) &
          stockLosses.lossDate.isSmallerOrEqualValue(endOfDay))
      ..orderBy([OrderingTerm.desc(stockLosses.lossDate)]);

    final results = await query.get();
    return results.map((row) {
      return StockLossWithProduct(
        stockLoss: row.readTable(stockLosses),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Get stock losses by type
  Future<List<StockLossWithProduct>> getStockLossesByType(
      LossType lossType) async {
    final query = select(stockLosses).join([
      innerJoin(products, products.id.equalsExp(stockLosses.productId)),
    ])
      ..where(stockLosses.lossType.equals(lossType.code))
      ..orderBy([OrderingTerm.desc(stockLosses.lossDate)]);

    final results = await query.get();
    return results.map((row) {
      return StockLossWithProduct(
        stockLoss: row.readTable(stockLosses),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Get stock loss by ID
  Future<StockLossesData?> getStockLossById(String id) {
    return (select(stockLosses)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // Create stock loss - generates number, deducts inventory, updates serial to DISPOSED
  Future<StockLossesData> createStockLoss({
    required String productId,
    required int quantity,
    String? serialNumberId,
    required LossType lossType,
    required String lossReason,
    required double unitCost,
    DateTime? lossDate,
    String? notes,
    String? createdBy,
  }) async {
    return transaction(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final lossNumber = await db.getNextSequenceNumber('STOCK_LOSS');
      final totalLossAmount = unitCost * quantity;

      // Insert stock loss record
      await into(stockLosses).insert(StockLossesCompanion.insert(
        id: id,
        lossNumber: lossNumber,
        productId: productId,
        quantity: quantity,
        serialNumberId: Value(serialNumberId),
        lossType: lossType.code,
        lossReason: lossReason,
        unitCost: unitCost,
        totalLossAmount: totalLossAmount,
        lossDate: lossDate ?? now,
        notes: Value(notes),
        createdBy: Value(createdBy),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ));

      // Deduct from inventory
      final inv = await (select(inventory)
            ..where((t) => t.productId.equals(productId)))
          .getSingleOrNull();

      if (inv != null) {
        await (update(inventory)..where((t) => t.productId.equals(productId)))
            .write(
          InventoryCompanion(
            quantityOnHand: Value(inv.quantityOnHand - quantity),
            totalCost: Value(inv.totalCost - totalLossAmount),
            lastStockDate: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('PENDING'),
            localUpdatedAt: Value(now),
          ),
        );
      }

      // If serialized item, update serial status to DISPOSED
      if (serialNumberId != null) {
        await db.inventoryDao.updateSerialStatus(
          serialId: serialNumberId,
          newStatus: SerialStatus.disposed,
          referenceType: 'STOCK_LOSS',
          referenceId: id,
          notes: 'Stock loss: ${lossType.displayName} - $lossReason',
          changedBy: createdBy,
        );
      }

      return (await getStockLossById(id))!;
    });
  }

  // Get loss summary for P&L integration
  Future<StockLossSummary> getLossSummary(
      DateTime startDate, DateTime endDate) async {
    final endOfDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final allLosses = await (select(stockLosses)
          ..where((t) =>
              t.lossDate.isBiggerOrEqualValue(startDate) &
              t.lossDate.isSmallerOrEqualValue(endOfDay)))
        .get();

    double totalAmount = 0;
    int totalCount = 0;
    final Map<String, double> typeBreakdown = {};
    final Map<String, int> typeCountBreakdown = {};

    for (final loss in allLosses) {
      totalAmount += loss.totalLossAmount;
      totalCount++;
      typeBreakdown[loss.lossType] =
          (typeBreakdown[loss.lossType] ?? 0) + loss.totalLossAmount;
      typeCountBreakdown[loss.lossType] =
          (typeCountBreakdown[loss.lossType] ?? 0) + 1;
    }

    return StockLossSummary(
      totalLossAmount: totalAmount,
      totalLossCount: totalCount,
      typeBreakdown: typeBreakdown,
      typeCountBreakdown: typeCountBreakdown,
    );
  }

  // Delete stock loss (not recommended in production, but useful for testing)
  Future<void> deleteStockLoss(String id) async {
    await (delete(stockLosses)..where((t) => t.id.equals(id))).go();
  }
}

// Helper classes
class StockLossWithProduct {
  final StockLossesData stockLoss;
  final Product product;

  StockLossWithProduct({
    required this.stockLoss,
    required this.product,
  });

  String get lossNumber => stockLoss.lossNumber;
  String get productName => product.name;
  String get productCode => product.code;
  int get quantity => stockLoss.quantity;
  double get unitCost => stockLoss.unitCost;
  double get totalLossAmount => stockLoss.totalLossAmount;
  DateTime get lossDate => stockLoss.lossDate;
  String get lossReason => stockLoss.lossReason;
  LossType get lossType => LossType.fromCode(stockLoss.lossType);
  String get lossTypeDisplayName => lossType.displayName;
}

class StockLossSummary {
  final double totalLossAmount;
  final int totalLossCount;
  final Map<String, double> typeBreakdown;
  final Map<String, int> typeCountBreakdown;

  StockLossSummary({
    required this.totalLossAmount,
    required this.totalLossCount,
    required this.typeBreakdown,
    required this.typeCountBreakdown,
  });

  double getLossAmountByType(LossType type) => typeBreakdown[type.code] ?? 0;
  int getLossCountByType(LossType type) => typeCountBreakdown[type.code] ?? 0;
}
