import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/product_type.dart';
import '../database/app_database.dart';
import '../tables/products_table.dart';
import '../tables/inventory_table.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products, Inventory])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  static const _uuid = Uuid();

  // Get all active products
  Future<List<Product>> getAllProducts() {
    return (select(products)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Watch all active products
  Stream<List<Product>> watchAllProducts() {
    return (select(products)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  // Get product by ID
  Future<Product?> getProductById(String id) {
    return (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get product by code
  Future<Product?> getProductByCode(String code) {
    return (select(products)..where((t) => t.code.equals(code))).getSingleOrNull();
  }

  // Get product by barcode
  Future<Product?> getProductByBarcode(String barcode) {
    return (select(products)..where((t) => t.barcode.equals(barcode))).getSingleOrNull();
  }

  // Get products by category
  Future<List<Product>> getProductsByCategory(String categoryId) {
    return (select(products)
          ..where((t) => t.categoryId.equals(categoryId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Get products by type
  Future<List<Product>> getProductsByType(ProductType type) {
    return (select(products)
          ..where((t) => t.productType.equals(type.code) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Get products requiring serial numbers
  Future<List<Product>> getSerializedProducts() {
    return (select(products)
          ..where((t) => t.requiresSerial.equals(true) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Insert product with inventory record
  Future<Product> insertProduct({
    required String code,
    required String name,
    String? barcode,
    String? description,
    String? categoryId,
    required ProductType productType,
    required bool requiresSerial,
    required double sellingPrice,
    double weightedAvgCost = 0,
    int warrantyMonths = 0,
    int reorderLevel = 5,
    String? brand,
    String? model,
    String? specifications,
  }) async {
    final productId = _uuid.v4();
    final inventoryId = _uuid.v4();
    final now = DateTime.now();

    await transaction(() async {
      // Insert product
      await into(products).insert(ProductsCompanion.insert(
        id: productId,
        code: code,
        name: name,
        barcode: Value(barcode),
        description: Value(description),
        categoryId: Value(categoryId),
        productType: Value(productType.code),
        requiresSerial: Value(requiresSerial),
        sellingPrice: Value(sellingPrice),
        weightedAvgCost: Value(weightedAvgCost),
        warrantyMonths: Value(warrantyMonths),
        reorderLevel: Value(reorderLevel),
        brand: Value(brand),
        model: Value(model),
        specifications: Value(specifications),
        isActive: const Value(true),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ));

      // Create inventory record
      await into(inventory).insert(InventoryCompanion.insert(
        id: inventoryId,
        productId: productId,
        quantityOnHand: const Value(0),
        totalCost: const Value(0),
        reservedQuantity: const Value(0),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ));
    });

    return (await getProductById(productId))!;
  }

  // Update product
  Future<bool> updateProduct({
    required String id,
    String? code,
    String? barcode,
    String? name,
    String? description,
    String? categoryId,
    ProductType? productType,
    bool? requiresSerial,
    double? sellingPrice,
    double? weightedAvgCost,
    int? warrantyMonths,
    int? reorderLevel,
    String? brand,
    String? model,
    String? specifications,
    bool? isActive,
  }) async {
    final now = DateTime.now();

    return await (update(products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        code: code != null ? Value(code) : const Value.absent(),
        barcode: Value(barcode),
        name: name != null ? Value(name) : const Value.absent(),
        description: Value(description),
        categoryId: Value(categoryId),
        productType: productType != null ? Value(productType.code) : const Value.absent(),
        requiresSerial: requiresSerial != null ? Value(requiresSerial) : const Value.absent(),
        sellingPrice: sellingPrice != null ? Value(sellingPrice) : const Value.absent(),
        weightedAvgCost: weightedAvgCost != null ? Value(weightedAvgCost) : const Value.absent(),
        warrantyMonths: warrantyMonths != null ? Value(warrantyMonths) : const Value.absent(),
        reorderLevel: reorderLevel != null ? Value(reorderLevel) : const Value.absent(),
        brand: Value(brand),
        model: Value(model),
        specifications: Value(specifications),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    ) > 0;
  }

  // Update WAC (called from GRN)
  Future<void> updateWeightedAvgCost(String productId, double newWAC) async {
    final now = DateTime.now();
    await (update(products)..where((t) => t.id.equals(productId))).write(
      ProductsCompanion(
        weightedAvgCost: Value(newWAC),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Soft delete product
  Future<bool> deleteProduct(String id) async {
    return await updateProduct(id: id, isActive: false);
  }

  // Search products
  Future<List<Product>> searchProducts(String query) {
    final searchTerm = '%$query%';
    return (select(products)
          ..where((t) =>
              (t.name.like(searchTerm) |
                  t.code.like(searchTerm) |
                  t.barcode.like(searchTerm) |
                  t.brand.like(searchTerm) |
                  t.model.like(searchTerm)) &
              t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Check if code exists
  Future<bool> isCodeExists(String code, {String? excludeId}) async {
    final query = select(products)..where((t) => t.code.equals(code));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // Check if barcode exists
  Future<bool> isBarcodeExists(String barcode, {String? excludeId}) async {
    final query = select(products)..where((t) => t.barcode.equals(barcode));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // Get low stock products
  Future<List<Product>> getLowStockProducts() async {
    final query = select(products).join([
      innerJoin(inventory, inventory.productId.equalsExp(products.id)),
    ])
      ..where(products.isActive.equals(true) &
          inventory.quantityOnHand.isSmallerOrEqual(products.reorderLevel));

    final results = await query.get();
    return results.map((row) => row.readTable(products)).toList();
  }
}
