import 'package:drift/drift.dart';
import 'products_table.dart';
import 'customers_table.dart';

class SerialNumbers extends Table {
  TextColumn get id => text()();
  TextColumn get serialNumber => text().unique()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get status => text().withDefault(const Constant('IN_STOCK'))(); // IN_STOCK, SOLD, RETURNED, IN_REPAIR, DEFECTIVE, DISPOSED
  RealColumn get unitCost => real().withDefault(const Constant(0.0))();
  TextColumn get grnId => text().nullable()();
  TextColumn get grnItemId => text().nullable()();
  TextColumn get saleId => text().nullable()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  DateTimeColumn get warrantyStartDate => dateTime().nullable()();
  DateTimeColumn get warrantyEndDate => dateTime().nullable()();
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

class SerialNumberHistory extends Table {
  TextColumn get id => text()();
  TextColumn get serialNumberId => text().references(SerialNumbers, #id)();
  TextColumn get fromStatus => text()();
  TextColumn get toStatus => text()();
  TextColumn get referenceType => text().nullable()(); // GRN, SALE, REPAIR, ADJUSTMENT
  TextColumn get referenceId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
