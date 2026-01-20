import 'package:drift/drift.dart';
import 'sales_table.dart';

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get paymentMethod => text()(); // CASH, CARD, BANK_TRANSFER, CHEQUE
  RealColumn get amount => real()();
  TextColumn get referenceNumber => text().nullable()(); // Card last 4, cheque no, bank ref
  DateTimeColumn get paymentDate => dateTime()();
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
}
