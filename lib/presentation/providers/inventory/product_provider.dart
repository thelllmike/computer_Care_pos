import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/product_type.dart';
import '../../../data/local/daos/product_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// DAO provider
final productDaoProvider = Provider<ProductDao>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductDao(db);
});

// All products stream
final productsProvider = StreamProvider<List<Product>>((ref) {
  final dao = ref.watch(productDaoProvider);
  return dao.watchAllProducts();
});

// Products by category
final productsByCategoryProvider = FutureProvider.family<List<Product>, String>((ref, categoryId) async {
  final dao = ref.watch(productDaoProvider);
  return dao.getProductsByCategory(categoryId);
});

// Products by type
final productsByTypeProvider = FutureProvider.family<List<Product>, ProductType>((ref, type) async {
  final dao = ref.watch(productDaoProvider);
  return dao.getProductsByType(type);
});

// Serialized products
final serializedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final dao = ref.watch(productDaoProvider);
  return dao.getSerializedProducts();
});

// Single product by ID
final productByIdProvider = FutureProvider.family<Product?, String>((ref, id) async {
  final dao = ref.watch(productDaoProvider);
  return dao.getProductById(id);
});

// Product by barcode
final productByBarcodeProvider = FutureProvider.family<Product?, String>((ref, barcode) async {
  final dao = ref.watch(productDaoProvider);
  return dao.getProductByBarcode(barcode);
});

// Search products
final productSearchProvider = FutureProvider.family<List<Product>, String>((ref, query) async {
  final dao = ref.watch(productDaoProvider);
  if (query.isEmpty) return [];
  return dao.searchProducts(query);
});

// Low stock products
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final dao = ref.watch(productDaoProvider);
  return dao.getLowStockProducts();
});

// Product form state
class ProductFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const ProductFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  ProductFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
  }) {
    return ProductFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

// Product form notifier
class ProductFormNotifier extends StateNotifier<ProductFormState> {
  final ProductDao _dao;
  final AppDatabase _db;

  ProductFormNotifier(this._dao, this._db) : super(const ProductFormState());

  Future<Product?> createProduct({
    required String name,
    String? barcode,
    String? description,
    String? categoryId,
    required ProductType productType,
    bool? requiresSerial,
    required double sellingPrice,
    int warrantyMonths = 0,
    int reorderLevel = 5,
    String? brand,
    String? model,
    String? specifications,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Generate code
      final code = await _db.getNextSequenceNumber('PRODUCT');

      // Check barcode uniqueness
      if (barcode != null && barcode.isNotEmpty) {
        if (await _dao.isBarcodeExists(barcode)) {
          state = state.copyWith(isLoading: false, error: 'Barcode already exists');
          return null;
        }
      }

      // Laptops require serial by default
      final needsSerial = requiresSerial ?? (productType == ProductType.laptop);

      final product = await _dao.insertProduct(
        code: code,
        name: name,
        barcode: barcode,
        description: description,
        categoryId: categoryId,
        productType: productType,
        requiresSerial: needsSerial,
        sellingPrice: sellingPrice,
        warrantyMonths: warrantyMonths,
        reorderLevel: reorderLevel,
        brand: brand,
        model: model,
        specifications: specifications,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
      return product;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> updateProduct({
    required String id,
    String? name,
    String? barcode,
    String? description,
    String? categoryId,
    ProductType? productType,
    bool? requiresSerial,
    double? sellingPrice,
    int? warrantyMonths,
    int? reorderLevel,
    String? brand,
    String? model,
    String? specifications,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check barcode uniqueness if changing
      if (barcode != null && barcode.isNotEmpty) {
        if (await _dao.isBarcodeExists(barcode, excludeId: id)) {
          state = state.copyWith(isLoading: false, error: 'Barcode already exists');
          return false;
        }
      }

      final success = await _dao.updateProduct(
        id: id,
        name: name,
        barcode: barcode,
        description: description,
        categoryId: categoryId,
        productType: productType,
        requiresSerial: requiresSerial,
        sellingPrice: sellingPrice,
        warrantyMonths: warrantyMonths,
        reorderLevel: reorderLevel,
        brand: brand,
        model: model,
        specifications: specifications,
        isActive: isActive,
      );

      state = state.copyWith(isLoading: false, isSuccess: success);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _dao.deleteProduct(id);
      state = state.copyWith(isLoading: false, isSuccess: success);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = const ProductFormState();
  }
}

final productFormProvider = StateNotifierProvider<ProductFormNotifier, ProductFormState>((ref) {
  final dao = ref.watch(productDaoProvider);
  final db = ref.watch(databaseProvider);
  return ProductFormNotifier(dao, db);
});
