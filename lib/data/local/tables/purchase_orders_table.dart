import 'package:drift/drift.dart';
import 'suppliers_table.dart';

class PurchaseOrders extends Table {
  TextColumn get id => text()();
  TextColumn get orderNumber => text().unique()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  DateTimeColumn get orderDate => dateTime()();
  DateTimeColumn get expectedDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))(); // DRAFT, CONFIRMED, PARTIALLY_RECEIVED, COMPLETED, CANCELLED
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
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

class PurchaseOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseOrderId => text().references(PurchaseOrders, #id)();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitCost => real()();
  RealColumn get totalCost => real()();
  IntColumn get receivedQuantity => integer().withDefault(const Constant(0))();
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
