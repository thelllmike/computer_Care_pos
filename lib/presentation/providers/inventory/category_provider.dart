import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/category_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// DAO provider
final categoryDaoProvider = Provider<CategoryDao>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryDao(db);
});

// All categories stream
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final dao = ref.watch(categoryDaoProvider);
  return dao.watchAllCategories();
});

// Root categories (no parent)
final rootCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getRootCategories();
});

// Subcategories for a parent
final subcategoriesProvider = FutureProvider.family<List<Category>, String>((ref, parentId) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getSubcategories(parentId);
});

// Single category by ID
final categoryByIdProvider = FutureProvider.family<Category?, String>((ref, id) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getCategoryById(id);
});

// Search categories
final categorySearchProvider = FutureProvider.family<List<Category>, String>((ref, query) async {
  final dao = ref.watch(categoryDaoProvider);
  if (query.isEmpty) return [];
  return dao.searchCategories(query);
});

// Category form state
class CategoryFormState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const CategoryFormState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  CategoryFormState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
  }) {
    return CategoryFormState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
    );
  }
}

// Category form notifier
class CategoryFormNotifier extends StateNotifier<CategoryFormState> {
  final CategoryDao _dao;
  final AppDatabase _db;

  CategoryFormNotifier(this._dao, this._db) : super(const CategoryFormState());

  Future<Category?> createCategory({
    required String name,
    String? description,
    String? parentId,
    int sortOrder = 0,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Generate code
      final code = await _db.getNextSequenceNumber('CATEGORY');

      // Check if code exists (shouldn't happen with sequences)
      if (await _dao.isCodeExists(code)) {
        state = state.copyWith(isLoading: false, error: 'Code already exists');
        return null;
      }

      final category = await _dao.insertCategory(
        code: code,
        name: name,
        description: description,
        parentId: parentId,
        sortOrder: sortOrder,
      );

      state = state.copyWith(isLoading: false, isSuccess: true);
      return category;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> updateCategory({
    required String id,
    String? name,
    String? description,
    String? parentId,
    int? sortOrder,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _dao.updateCategory(
        id: id,
        name: name,
        description: description,
        parentId: parentId,
        sortOrder: sortOrder,
        isActive: isActive,
      );

      state = state.copyWith(isLoading: false, isSuccess: success);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _dao.deleteCategory(id);
      state = state.copyWith(isLoading: false, isSuccess: success);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = const CategoryFormState();
  }
}

final categoryFormProvider = StateNotifierProvider<CategoryFormNotifier, CategoryFormState>((ref) {
  final dao = ref.watch(categoryDaoProvider);
  final db = ref.watch(databaseProvider);
  return CategoryFormNotifier(dao, db);
});
