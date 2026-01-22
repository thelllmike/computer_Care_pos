import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/payment_method.dart';
import '../../../data/local/daos/credit_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// Provider for credit summary
final creditSummaryProvider = FutureProvider<CreditSummary>((ref) {
  final db = ref.watch(databaseProvider);
  return db.creditDao.getCreditSummary();
});

// Provider for customers with outstanding balance
final outstandingCustomersProvider = FutureProvider<List<CustomerWithCredit>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.creditDao.getCustomersWithOutstanding();
});

// Provider for aging summary
final agingSummaryProvider = FutureProvider<AgingSummary>((ref) {
  final db = ref.watch(databaseProvider);
  return db.creditDao.getAgingSummary();
});

// Provider for aging by customer
final agingByCustomerProvider = FutureProvider<List<CustomerAging>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.creditDao.getAgingByCustomer();
});

// Provider for outstanding sales of a specific customer
final customerOutstandingSalesProvider = FutureProvider.family<List<OutstandingSale>, String>((ref, customerId) {
  final db = ref.watch(databaseProvider);
  return db.creditDao.getOutstandingSales(customerId);
});

// Provider for customer statement
final customerStatementProvider = FutureProvider.family<List<CreditTransactionWithDetails>, CustomerStatementParams>((ref, params) {
  final db = ref.watch(databaseProvider);
  return db.creditDao.getCustomerStatement(
    params.customerId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

// Helper class for statement params
class CustomerStatementParams {
  final String customerId;
  final DateTime? startDate;
  final DateTime? endDate;

  CustomerStatementParams({
    required this.customerId,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerStatementParams &&
        other.customerId == customerId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(customerId, startDate, endDate);
}

// ==================== Payment Collection State ====================

class PaymentCollectionState {
  final bool isProcessing;
  final bool isSuccess;
  final String? error;
  final CreditTransaction? completedTransaction;

  PaymentCollectionState({
    this.isProcessing = false,
    this.isSuccess = false,
    this.error,
    this.completedTransaction,
  });

  PaymentCollectionState copyWith({
    bool? isProcessing,
    bool? isSuccess,
    String? error,
    CreditTransaction? completedTransaction,
  }) {
    return PaymentCollectionState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      completedTransaction: completedTransaction ?? this.completedTransaction,
    );
  }
}

class PaymentCollectionNotifier extends StateNotifier<PaymentCollectionState> {
  final AppDatabase _db;
  final Ref _ref;

  PaymentCollectionNotifier(this._db, this._ref) : super(PaymentCollectionState());

  Future<void> recordPayment({
    required String customerId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? saleId,
    String? referenceNumber,
    String? notes,
    String? createdBy,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final transaction = await _db.creditDao.recordPayment(
        customerId: customerId,
        amount: amount,
        paymentMethod: paymentMethod,
        saleId: saleId,
        referenceNumber: referenceNumber,
        notes: notes,
        createdBy: createdBy,
      );

      // Invalidate related providers
      _ref.invalidate(creditSummaryProvider);
      _ref.invalidate(outstandingCustomersProvider);
      _ref.invalidate(agingSummaryProvider);
      _ref.invalidate(agingByCustomerProvider);
      _ref.invalidate(customerOutstandingSalesProvider(customerId));

      state = state.copyWith(
        isProcessing: false,
        isSuccess: true,
        completedTransaction: transaction,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
    }
  }

  Future<void> recordAdjustment({
    required String customerId,
    required double amount,
    required String reason,
    String? createdBy,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final transaction = await _db.creditDao.recordAdjustment(
        customerId: customerId,
        amount: amount,
        reason: reason,
        createdBy: createdBy,
      );

      // Invalidate related providers
      _ref.invalidate(creditSummaryProvider);
      _ref.invalidate(outstandingCustomersProvider);
      _ref.invalidate(agingSummaryProvider);
      _ref.invalidate(agingByCustomerProvider);

      state = state.copyWith(
        isProcessing: false,
        isSuccess: true,
        completedTransaction: transaction,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
    }
  }

  void reset() {
    state = PaymentCollectionState();
  }
}

final paymentCollectionProvider = StateNotifierProvider<PaymentCollectionNotifier, PaymentCollectionState>((ref) {
  final db = ref.watch(databaseProvider);
  return PaymentCollectionNotifier(db, ref);
});

// ==================== Selected Customer State ====================

final selectedCreditCustomerProvider = StateProvider<CustomerWithCredit?>((ref) => null);

// ==================== Search and Filter State ====================

final creditSearchQueryProvider = StateProvider<String>((ref) => '');

enum CreditFilterType {
  all,
  current,
  overdue30,
  overdue60,
  overdue90,
}

final creditFilterProvider = StateProvider<CreditFilterType>((ref) => CreditFilterType.all);
