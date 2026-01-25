import 'package:drift/drift.dart';

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get expenseNumber => text().unique()();
  TextColumn get category => text()(); // ELECTRICITY, WATER, RENT, INTERNET, SALARY, OTHER
  TextColumn get description => text()();
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get paymentMethod => text().nullable()(); // CASH, BANK, CARD
  TextColumn get referenceNumber => text().nullable()(); // Bill/Receipt number
  TextColumn get vendor => text().nullable()(); // e.g., Ceylon Electricity Board
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

// Expense category enum for type safety
enum ExpenseCategory {
  electricity('ELECTRICITY', 'Electricity'),
  water('WATER', 'Water'),
  rent('RENT', 'Rent'),
  internet('INTERNET', 'Internet'),
  telephone('TELEPHONE', 'Telephone'),
  salary('SALARY', 'Salary'),
  supplies('SUPPLIES', 'Office Supplies'),
  maintenance('MAINTENANCE', 'Maintenance'),
  transport('TRANSPORT', 'Transport'),
  other('OTHER', 'Other');

  final String code;
  final String displayName;

  const ExpenseCategory(this.code, this.displayName);

  static ExpenseCategory fromCode(String code) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ExpenseCategory.other,
    );
  }
}
