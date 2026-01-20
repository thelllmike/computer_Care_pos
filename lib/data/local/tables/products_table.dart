import 'package:drift/drift.dart';
import 'categories_table.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get productType => text().withDefault(const Constant('ACCESSORY'))(); // LAPTOP, ACCESSORY, SPARE_PART
  BoolColumn get requiresSerial => boolean().withDefault(const Constant(false))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0.0))();
  RealColumn get weightedAvgCost => real().withDefault(const Constant(0.0))();
  IntColumn get warrantyMonths => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(5))();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get specifications => text().nullable()(); // JSON string for specs
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
