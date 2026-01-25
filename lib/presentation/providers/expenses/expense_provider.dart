import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/expense_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/local/tables/expenses_table.dart';
import '../core/database_provider.dart';

// Provider for all expenses
final expensesProvider = FutureProvider<List<Expense>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.expenseDao.getAllExpenses();
});

// Provider for expenses by date range
final expensesByDateRangeProvider = FutureProvider.family<List<Expense>, DateRangeParams>((ref, params) {
  final db = ref.watch(databaseProvider);
  return db.expenseDao.getExpensesByDateRange(params.startDate, params.endDate);
});

// Provider for expense summary
final expenseSummaryProvider = FutureProvider.family<ExpenseSummary, DateRangeParams>((ref, params) {
  final db = ref.watch(databaseProvider);
  return db.expenseDao.getExpenseSummary(params.startDate, params.endDate);
});

// Provider for category summary
final expenseCategorySummaryProvider = FutureProvider.family<List<ExpenseCategorySummary>, DateRangeParams>((ref, params) {
  final db = ref.watch(databaseProvider);
  return db.expenseDao.getExpenseSummaryByCategory(params.startDate, params.endDate);
});

// Provider for monthly expenses
final monthlyExpensesProvider = FutureProvider.family<List<MonthlyExpense>, int>((ref, year) {
  final db = ref.watch(databaseProvider);
  return db.expenseDao.getMonthlyExpenses(year);
});

// Date range params helper
class DateRangeParams {
  final DateTime startDate;
  final DateTime endDate;

  DateRangeParams({required this.startDate, required this.endDate});

  factory DateRangeParams.thisMonth() {
    final now = DateTime.now();
    return DateRangeParams(
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  factory DateRangeParams.thisYear() {
    final now = DateTime.now();
    return DateRangeParams(
      startDate: DateTime(now.year, 1, 1),
      endDate: DateTime(now.year, 12, 31, 23, 59, 59),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRangeParams &&
        other.startDate.year == startDate.year &&
        other.startDate.month == startDate.month &&
        other.startDate.day == startDate.day &&
        other.endDate.year == endDate.year &&
        other.endDate.month == endDate.month &&
        other.endDate.day == endDate.day;
  }

  @override
  int get hashCode => Object.hash(
        startDate.year,
        startDate.month,
        startDate.day,
        endDate.year,
        endDate.month,
        endDate.day,
      );
}

// ==================== Expense Form State ====================

class ExpenseFormState {
  final String? expenseId;
  final String category;
  final String description;
  final double amount;
  final DateTime expenseDate;
  final String? paymentMethod;
  final String? referenceNumber;
  final String? vendor;
  final String? notes;
  final bool isSaving;
  final String? error;

  ExpenseFormState({
    this.expenseId,
    this.category = 'OTHER',
    this.description = '',
    this.amount = 0,
    DateTime? expenseDate,
    this.paymentMethod,
    this.referenceNumber,
    this.vendor,
    this.notes,
    this.isSaving = false,
    this.error,
  }) : expenseDate = expenseDate ?? DateTime.now();

  bool get isEditing => expenseId != null;
  bool get isValid => description.isNotEmpty && amount > 0;

  ExpenseFormState copyWith({
    String? expenseId,
    String? category,
    String? description,
    double? amount,
    DateTime? expenseDate,
    String? paymentMethod,
    String? referenceNumber,
    String? vendor,
    String? notes,
    bool? isSaving,
    String? error,
  }) {
    return ExpenseFormState(
      expenseId: expenseId ?? this.expenseId,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      vendor: vendor ?? this.vendor,
      notes: notes ?? this.notes,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class ExpenseFormNotifier extends StateNotifier<ExpenseFormState> {
  final AppDatabase _db;
  final Ref _ref;

  ExpenseFormNotifier(this._db, this._ref) : super(ExpenseFormState());

  void setCategory(String category) {
    state = state.copyWith(category: category);
  }

  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setAmount(double amount) {
    state = state.copyWith(amount: amount);
  }

  void setExpenseDate(DateTime date) {
    state = state.copyWith(expenseDate: date);
  }

  void setPaymentMethod(String? method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setReferenceNumber(String? ref) {
    state = state.copyWith(referenceNumber: ref);
  }

  void setVendor(String? vendor) {
    state = state.copyWith(vendor: vendor);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  Future<Expense?> saveExpense({String? createdBy}) async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Please fill in all required fields');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      Expense expense;

      if (state.isEditing) {
        await _db.expenseDao.updateExpense(
          id: state.expenseId!,
          category: state.category,
          description: state.description,
          amount: state.amount,
          expenseDate: state.expenseDate,
          paymentMethod: state.paymentMethod,
          referenceNumber: state.referenceNumber,
          vendor: state.vendor,
          notes: state.notes,
        );
        expense = (await _db.expenseDao.getExpenseById(state.expenseId!))!;
      } else {
        expense = await _db.expenseDao.createExpense(
          category: state.category,
          description: state.description,
          amount: state.amount,
          expenseDate: state.expenseDate,
          paymentMethod: state.paymentMethod,
          referenceNumber: state.referenceNumber,
          vendor: state.vendor,
          notes: state.notes,
          createdBy: createdBy,
        );
      }

      // Invalidate providers
      _ref.invalidate(expensesProvider);

      state = state.copyWith(isSaving: false);
      return expense;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<void> loadExpense(String expenseId) async {
    try {
      final expense = await _db.expenseDao.getExpenseById(expenseId);
      if (expense != null) {
        state = ExpenseFormState(
          expenseId: expense.id,
          category: expense.category,
          description: expense.description,
          amount: expense.amount,
          expenseDate: expense.expenseDate,
          paymentMethod: expense.paymentMethod,
          referenceNumber: expense.referenceNumber,
          vendor: expense.vendor,
          notes: expense.notes,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clear() {
    state = ExpenseFormState();
  }
}

final expenseFormProvider = StateNotifierProvider<ExpenseFormNotifier, ExpenseFormState>((ref) {
  final db = ref.watch(databaseProvider);
  return ExpenseFormNotifier(db, ref);
});

// Delete expense provider
final deleteExpenseProvider = FutureProvider.family<void, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  await db.expenseDao.deleteExpense(id);
  ref.invalidate(expensesProvider);
});
