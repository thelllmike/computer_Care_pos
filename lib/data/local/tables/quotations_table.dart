import 'package:drift/drift.dart';
import 'customers_table.dart';

class Quotations extends Table {
  TextColumn get id => text()();
  TextColumn get quotationNumber => text().unique()();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  DateTimeColumn get quotationDate => dateTime()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))(); // DRAFT, SENT, ACCEPTED, REJECTED, EXPIRED, CONVERTED
  TextColumn get convertedSaleId => text().nullable()();
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

class QuotationItems extends Table {
  TextColumn get id => text()();
  TextColumn get quotationId => text().references(Quotations, #id)();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real()();
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
