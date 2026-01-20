import 'package:drift/drift.dart';
import 'products_table.dart';

class Inventory extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantityOnHand => integer().withDefault(const Constant(0))();
  RealColumn get totalCost => real().withDefault(const Constant(0.0))(); // For WAC calculation
  IntColumn get reservedQuantity => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastStockDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
