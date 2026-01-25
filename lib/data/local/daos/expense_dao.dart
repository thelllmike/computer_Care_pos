import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../tables/expenses_table.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  static const _uuid = Uuid();

  // Get all expenses
  Future<List<Expense>> getAllExpenses() {
    return (select(expenses)..orderBy([(t) => OrderingTerm.desc(t.expenseDate)])).get();
  }

  // Get expenses by date range
  Future<List<Expense>> getExpensesByDateRange(DateTime startDate, DateTime endDate) {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return (select(expenses)
          ..where((t) => t.expenseDate.isBiggerOrEqualValue(startDate) &
                         t.expenseDate.isSmallerOrEqualValue(endOfDay))
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();
  }

  // Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) {
    return (select(expenses)
          ..where((t) => t.category.equals(category))
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();
  }

  // Get expense by ID
  Future<Expense?> getExpenseById(String id) {
    return (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Create expense
  Future<Expense> createExpense({
    required String category,
    required String description,
    required double amount,
    required DateTime expenseDate,
    String? paymentMethod,
    String? referenceNumber,
    String? vendor,
    String? notes,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final expenseNumber = await db.getNextSequenceNumber('EXPENSE');

    await into(expenses).insert(ExpensesCompanion.insert(
      id: id,
      expenseNumber: expenseNumber,
      category: category,
      description: description,
      amount: amount,
      expenseDate: expenseDate,
      paymentMethod: Value(paymentMethod),
      referenceNumber: Value(referenceNumber),
      vendor: Value(vendor),
      notes: Value(notes),
      createdBy: Value(createdBy),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    return (await getExpenseById(id))!;
  }

  // Update expense
  Future<void> updateExpense({
    required String id,
    String? category,
    String? description,
    double? amount,
    DateTime? expenseDate,
    String? paymentMethod,
    String? referenceNumber,
    String? vendor,
    String? notes,
  }) async {
    final now = DateTime.now();

    await (update(expenses)..where((t) => t.id.equals(id))).write(
      ExpensesCompanion(
        category: category != null ? Value(category) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        expenseDate: expenseDate != null ? Value(expenseDate) : const Value.absent(),
        paymentMethod: paymentMethod != null ? Value(paymentMethod) : const Value.absent(),
        referenceNumber: referenceNumber != null ? Value(referenceNumber) : const Value.absent(),
        vendor: vendor != null ? Value(vendor) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Delete expense
  Future<void> deleteExpense(String id) async {
    await (delete(expenses)..where((t) => t.id.equals(id))).go();
  }

  // Get expense summary by category for date range
  Future<List<ExpenseCategorySummary>> getExpenseSummaryByCategory(DateTime startDate, DateTime endDate) async {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final allExpenses = await (select(expenses)
          ..where((t) => t.expenseDate.isBiggerOrEqualValue(startDate) &
                         t.expenseDate.isSmallerOrEqualValue(endOfDay)))
        .get();

    final Map<String, double> categoryTotals = {};
    for (final expense in allExpenses) {
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    return categoryTotals.entries
        .map((e) => ExpenseCategorySummary(category: e.key, totalAmount: e.value))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  // Get total expenses for date range
  Future<ExpenseSummary> getExpenseSummary(DateTime startDate, DateTime endDate) async {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final allExpenses = await (select(expenses)
          ..where((t) => t.expenseDate.isBiggerOrEqualValue(startDate) &
                         t.expenseDate.isSmallerOrEqualValue(endOfDay)))
        .get();

    double totalAmount = 0;
    final Map<String, double> categoryTotals = {};

    for (final expense in allExpenses) {
      totalAmount += expense.amount;
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    return ExpenseSummary(
      totalExpenses: allExpenses.length,
      totalAmount: totalAmount,
      categoryBreakdown: categoryTotals,
    );
  }

  // Get monthly expenses for the current year
  Future<List<MonthlyExpense>> getMonthlyExpenses(int year) async {
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

    final allExpenses = await (select(expenses)
          ..where((t) => t.expenseDate.isBiggerOrEqualValue(startOfYear) &
                         t.expenseDate.isSmallerOrEqualValue(endOfYear)))
        .get();

    final Map<int, double> monthlyTotals = {};
    for (final expense in allExpenses) {
      final month = expense.expenseDate.month;
      monthlyTotals[month] = (monthlyTotals[month] ?? 0) + expense.amount;
    }

    return List.generate(12, (index) {
      final month = index + 1;
      return MonthlyExpense(month: month, amount: monthlyTotals[month] ?? 0);
    });
  }
}

// Helper classes
class ExpenseCategorySummary {
  final String category;
  final double totalAmount;

  ExpenseCategorySummary({
    required this.category,
    required this.totalAmount,
  });

  String get categoryDisplayName => ExpenseCategory.fromCode(category).displayName;
}

class ExpenseSummary {
  final int totalExpenses;
  final double totalAmount;
  final Map<String, double> categoryBreakdown;

  ExpenseSummary({
    required this.totalExpenses,
    required this.totalAmount,
    required this.categoryBreakdown,
  });
}

class MonthlyExpense {
  final int month;
  final double amount;

  MonthlyExpense({
    required this.month,
    required this.amount,
  });

  String get monthName {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
