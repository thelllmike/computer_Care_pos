import 'package:drift/drift.dart';
import 'customers_table.dart';

class CreditTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get transactionType => text()(); // SALE (debit), PAYMENT (credit), ADJUSTMENT
  TextColumn get referenceType => text().nullable()(); // SALE, PAYMENT_RECEIPT
  TextColumn get referenceId => text().nullable()();
  RealColumn get amount => real()();
  RealColumn get balanceAfter => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
