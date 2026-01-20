import 'package:drift/drift.dart';
import 'suppliers_table.dart';

@DataClassName('GrnData')
class Grn extends Table {
  TextColumn get id => text()();
  TextColumn get grnNumber => text().unique()();
  TextColumn get purchaseOrderId => text().nullable()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get invoiceNumber => text().nullable()();
  DateTimeColumn get invoiceDate => dateTime().nullable()();
  DateTimeColumn get receivedDate => dateTime()();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  TextColumn get receivedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'grn';
}

class GrnItems extends Table {
  TextColumn get id => text()();
  TextColumn get grnId => text().references(Grn, #id)();
  TextColumn get productId => text()();
  TextColumn get purchaseOrderItemId => text().nullable()();
  IntColumn get quantity => integer()();
  RealColumn get unitCost => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class GrnSerials extends Table {
  TextColumn get id => text()();
  TextColumn get grnItemId => text().references(GrnItems, #id)();
  TextColumn get serialNumberId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
