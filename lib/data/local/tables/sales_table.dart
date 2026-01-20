import 'package:drift/drift.dart';
import 'customers_table.dart';

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text().unique()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get quotationId => text().nullable()();
  DateTimeColumn get saleDate => dateTime()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalCost => real().withDefault(const Constant(0.0))(); // COGS
  RealColumn get grossProfit => real().withDefault(const Constant(0.0))();
  BoolColumn get isCredit => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('COMPLETED'))(); // COMPLETED, RETURNED, PARTIALLY_RETURNED
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get unitCost => real()(); // WAC at time of sale
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real()();
  RealColumn get totalCost => real()();
  RealColumn get profit => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleSerials extends Table {
  TextColumn get id => text()();
  TextColumn get saleItemId => text().references(SaleItems, #id)();
  TextColumn get serialNumberId => text()();
  TextColumn get serialNumber => text()();
  RealColumn get unitCost => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
