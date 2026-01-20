import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  static const _uuid = Uuid();

  // Get all active categories
  Future<List<Category>> getAllCategories() {
    return (select(categories)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  // Get all categories including inactive
  Future<List<Category>> getAllCategoriesIncludingInactive() {
    return (select(categories)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  // Watch all active categories
  Stream<List<Category>> watchAllCategories() {
    return (select(categories)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  // Get category by ID
  Future<Category?> getCategoryById(String id) {
    return (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get category by code
  Future<Category?> getCategoryByCode(String code) {
    return (select(categories)..where((t) => t.code.equals(code))).getSingleOrNull();
  }

  // Get subcategories
  Future<List<Category>> getSubcategories(String parentId) {
    return (select(categories)
          ..where((t) => t.parentId.equals(parentId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  // Get root categories (no parent)
  Future<List<Category>> getRootCategories() {
    return (select(categories)
          ..where((t) => t.parentId.isNull() & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  // Insert category
  Future<Category> insertCategory({
    required String code,
    required String name,
    String? description,
    String? parentId,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = CategoriesCompanion.insert(
      id: id,
      code: code,
      name: name,
      description: Value(description),
      parentId: Value(parentId),
      sortOrder: Value(sortOrder),
      isActive: const Value(true),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    );

    await into(categories).insert(companion);
    return (await getCategoryById(id))!;
  }

  // Update category
  Future<bool> updateCategory({
    required String id,
    String? code,
    String? name,
    String? description,
    String? parentId,
    int? sortOrder,
    bool? isActive,
  }) async {
    final now = DateTime.now();

    return await (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        code: code != null ? Value(code) : const Value.absent(),
        name: name != null ? Value(name) : const Value.absent(),
        description: Value(description),
        parentId: Value(parentId),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    ) > 0;
  }

  // Soft delete category
  Future<bool> deleteCategory(String id) async {
    return await updateCategory(id: id, isActive: false);
  }

  // Hard delete category
  Future<bool> permanentlyDeleteCategory(String id) async {
    return await (delete(categories)..where((t) => t.id.equals(id))).go() > 0;
  }

  // Search categories
  Future<List<Category>> searchCategories(String query) {
    final searchTerm = '%$query%';
    return (select(categories)
          ..where((t) =>
              (t.name.like(searchTerm) | t.code.like(searchTerm)) &
              t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Check if code exists
  Future<bool> isCodeExists(String code, {String? excludeId}) async {
    final query = select(categories)..where((t) => t.code.equals(code));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    final result = await query.getSingleOrNull();
    return result != null;
  }
}
