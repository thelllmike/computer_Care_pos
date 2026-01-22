import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/payment_method.dart';
import '../database/app_database.dart';
import '../tables/customers_table.dart';
import '../tables/credit_transactions_table.dart';
import '../tables/sales_table.dart';
import '../tables/payments_table.dart';

part 'credit_dao.g.dart';

// Transaction type enum
enum CreditTransactionType {
  sale,
  payment,
  adjustment,
}

extension CreditTransactionTypeExtension on CreditTransactionType {
  String get code {
    switch (this) {
      case CreditTransactionType.sale:
        return 'SALE';
      case CreditTransactionType.payment:
        return 'PAYMENT';
      case CreditTransactionType.adjustment:
        return 'ADJUSTMENT';
    }
  }

  String get displayName {
    switch (this) {
      case CreditTransactionType.sale:
        return 'Sale (Credit)';
      case CreditTransactionType.payment:
        return 'Payment Received';
      case CreditTransactionType.adjustment:
        return 'Adjustment';
    }
  }

  static CreditTransactionType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SALE':
        return CreditTransactionType.sale;
      case 'PAYMENT':
        return CreditTransactionType.payment;
      case 'ADJUSTMENT':
        return CreditTransactionType.adjustment;
      default:
        return CreditTransactionType.sale;
    }
  }
}

@DriftAccessor(tables: [
  CreditTransactions,
  Customers,
  Sales,
  Payments,
])
class CreditDao extends DatabaseAccessor<AppDatabase> with _$CreditDaoMixin {
  CreditDao(super.db);

  static const _uuid = Uuid();

  // ==================== Outstanding/Receivables ====================

  // Get all customers with outstanding balance
  Future<List<CustomerWithCredit>> getCustomersWithOutstanding() async {
    final query = select(customers)
      ..where((c) => c.creditBalance.isBiggerThanValue(0))
      ..orderBy([(c) => OrderingTerm.desc(c.creditBalance)]);

    final results = await query.get();
    return results.map((c) => CustomerWithCredit(customer: c)).toList();
  }

  // Get all credit-enabled customers
  Future<List<CustomerWithCredit>> getCreditCustomers() async {
    final query = select(customers)
      ..where((c) => c.creditEnabled.equals(true))
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);

    final results = await query.get();
    return results.map((c) => CustomerWithCredit(customer: c)).toList();
  }

  // Get outstanding sales for a customer
  Future<List<OutstandingSale>> getOutstandingSales(String customerId) async {
    final query = select(sales)
      ..where((s) =>
          s.customerId.equals(customerId) &
          s.isCredit.equals(true) &
          s.status.equals('COMPLETED'))
      ..orderBy([(s) => OrderingTerm.asc(s.saleDate)]);

    final results = await query.get();

    // Calculate outstanding for each sale
    final outstandingSales = <OutstandingSale>[];
    for (final sale in results) {
      final paid = await _getTotalPaidForSale(sale.id);
      final outstanding = sale.totalAmount - paid;
      if (outstanding > 0.01) {
        // Small threshold for floating point
        outstandingSales.add(OutstandingSale(
          sale: sale,
          paidAmount: paid,
          outstandingAmount: outstanding,
          daysSinceSale: DateTime.now().difference(sale.saleDate).inDays,
        ));
      }
    }

    return outstandingSales;
  }

  // Get total paid amount for a specific sale
  Future<double> _getTotalPaidForSale(String saleId) async {
    final result = await (select(payments)
          ..where((p) => p.saleId.equals(saleId)))
        .get();

    double total = 0.0;
    for (final p in result) {
      total += p.amount;
    }
    return total;
  }

  // ==================== Aging Report ====================

  // Get aging summary for all customers
  Future<AgingSummary> getAgingSummary() async {
    final outstandingCustomers = await getCustomersWithOutstanding();
    final now = DateTime.now();

    double current = 0;
    double days30 = 0;
    double days60 = 0;
    double days90 = 0;
    double over90 = 0;

    for (final customerCredit in outstandingCustomers) {
      final outstandingSales =
          await getOutstandingSales(customerCredit.customer.id);

      for (final os in outstandingSales) {
        final days = os.daysSinceSale;
        if (days <= 30) {
          current += os.outstandingAmount;
        } else if (days <= 60) {
          days30 += os.outstandingAmount;
        } else if (days <= 90) {
          days60 += os.outstandingAmount;
        } else {
          days90 += os.outstandingAmount;
        }
      }
    }

    over90 = days90; // This is actually 90+ days

    return AgingSummary(
      current: current,
      days1to30: days30,
      days31to60: days60,
      days61to90: days90,
      over90: over90,
      total: current + days30 + days60 + days90,
    );
  }

  // Get aging detail by customer
  Future<List<CustomerAging>> getAgingByCustomer() async {
    final outstandingCustomers = await getCustomersWithOutstanding();
    final agingList = <CustomerAging>[];

    for (final customerCredit in outstandingCustomers) {
      final outstandingSales =
          await getOutstandingSales(customerCredit.customer.id);

      double current = 0;
      double days30 = 0;
      double days60 = 0;
      double days90 = 0;
      int oldestDays = 0;

      for (final os in outstandingSales) {
        final days = os.daysSinceSale;
        if (days > oldestDays) oldestDays = days;

        if (days <= 30) {
          current += os.outstandingAmount;
        } else if (days <= 60) {
          days30 += os.outstandingAmount;
        } else if (days <= 90) {
          days60 += os.outstandingAmount;
        } else {
          days90 += os.outstandingAmount;
        }
      }

      agingList.add(CustomerAging(
        customer: customerCredit.customer,
        current: current,
        days1to30: days30,
        days31to60: days60,
        days61to90: days90,
        over90: days90,
        total: customerCredit.customer.creditBalance,
        oldestInvoiceDays: oldestDays,
      ));
    }

    // Sort by total outstanding descending
    agingList.sort((a, b) => b.total.compareTo(a.total));
    return agingList;
  }

  // ==================== Payment Collection ====================

  // Record a payment against a customer's credit
  Future<CreditTransaction> recordPayment({
    required String customerId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? saleId,
    String? referenceNumber,
    String? notes,
    String? createdBy,
  }) async {
    return transaction(() async {
      // Get current customer balance
      final customer = await (select(customers)
            ..where((c) => c.id.equals(customerId)))
          .getSingle();

      final newBalance = customer.creditBalance - amount;

      // Update customer balance
      await (update(customers)..where((c) => c.id.equals(customerId))).write(
        CustomersCompanion(
          creditBalance: Value(newBalance < 0 ? 0 : newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // If payment is for a specific sale, record it in payments table
      if (saleId != null) {
        final paymentId = _uuid.v4();
        await into(payments).insert(PaymentsCompanion.insert(
          id: paymentId,
          saleId: saleId,
          paymentMethod: paymentMethod.code,
          amount: amount,
          referenceNumber: Value(referenceNumber),
          paymentDate: DateTime.now(),
        ));

        // Update sale paid amount
        final sale = await (select(sales)..where((s) => s.id.equals(saleId)))
            .getSingle();
        await (update(sales)..where((s) => s.id.equals(saleId))).write(
          SalesCompanion(
            paidAmount: Value(sale.paidAmount + amount),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      // Record credit transaction
      final txnId = _uuid.v4();
      final txn = CreditTransactionsCompanion.insert(
        id: txnId,
        customerId: customerId,
        transactionType: CreditTransactionType.payment.code,
        referenceType: Value(saleId != null ? 'SALE' : 'PAYMENT_RECEIPT'),
        referenceId: Value(saleId ?? referenceNumber),
        amount: amount,
        balanceAfter: newBalance < 0 ? 0 : newBalance,
        notes: Value(notes),
        createdBy: Value(createdBy),
        transactionDate: DateTime.now(),
      );

      await into(creditTransactions).insert(txn);

      return (await (select(creditTransactions)
                ..where((t) => t.id.equals(txnId)))
              .getSingle());
    });
  }

  // Record credit adjustment (positive increases balance, negative decreases)
  Future<CreditTransaction> recordAdjustment({
    required String customerId,
    required double amount,
    required String reason,
    String? createdBy,
  }) async {
    return transaction(() async {
      final customer = await (select(customers)
            ..where((c) => c.id.equals(customerId)))
          .getSingle();

      final newBalance = customer.creditBalance + amount;

      await (update(customers)..where((c) => c.id.equals(customerId))).write(
        CustomersCompanion(
          creditBalance: Value(newBalance < 0 ? 0 : newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final txnId = _uuid.v4();
      final txn = CreditTransactionsCompanion.insert(
        id: txnId,
        customerId: customerId,
        transactionType: CreditTransactionType.adjustment.code,
        referenceType: const Value(null),
        referenceId: const Value(null),
        amount: amount.abs(),
        balanceAfter: newBalance < 0 ? 0 : newBalance,
        notes: Value(reason),
        createdBy: Value(createdBy),
        transactionDate: DateTime.now(),
      );

      await into(creditTransactions).insert(txn);

      return (await (select(creditTransactions)
                ..where((t) => t.id.equals(txnId)))
              .getSingle());
    });
  }

  // ==================== Customer Statement ====================

  // Get all credit transactions for a customer
  Future<List<CreditTransactionWithDetails>> getCustomerStatement(
    String customerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = select(creditTransactions)
      ..where((t) => t.customerId.equals(customerId));

    if (startDate != null) {
      query = query
        ..where((t) => t.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query = query
        ..where((t) => t.transactionDate.isSmallerOrEqualValue(endDate));
    }

    query = query..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]);

    final results = await query.get();

    final detailedTxns = <CreditTransactionWithDetails>[];
    for (final txn in results) {
      Sale? relatedSale;
      if (txn.referenceType == 'SALE' && txn.referenceId != null) {
        relatedSale = await (select(sales)
              ..where((s) => s.id.equals(txn.referenceId!)))
            .getSingleOrNull();
      }

      detailedTxns.add(CreditTransactionWithDetails(
        transaction: txn,
        relatedSale: relatedSale,
      ));
    }

    return detailedTxns;
  }

  // ==================== Summary Statistics ====================

  // Get credit summary
  Future<CreditSummary> getCreditSummary() async {
    // Total outstanding
    final totalOutstanding = await (selectOnly(customers)
          ..addColumns([customers.creditBalance.sum()]))
        .map((row) => row.read(customers.creditBalance.sum()) ?? 0.0)
        .getSingle();

    // Number of credit customers
    final creditCustomersCount = await (selectOnly(customers)
          ..addColumns([customers.id.count()])
          ..where(customers.creditBalance.isBiggerThanValue(0)))
        .map((row) => row.read(customers.id.count()) ?? 0)
        .getSingle();

    // Payments collected this month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final paymentsThisMonth = await (selectOnly(creditTransactions)
          ..addColumns([creditTransactions.amount.sum()])
          ..where(creditTransactions.transactionType.equals('PAYMENT') &
              creditTransactions.transactionDate
                  .isBiggerOrEqualValue(startOfMonth)))
        .map((row) => row.read(creditTransactions.amount.sum()) ?? 0.0)
        .getSingle();

    // Overdue amount (30+ days)
    final aging = await getAgingSummary();
    final overdueAmount =
        aging.days1to30 + aging.days31to60 + aging.days61to90 + aging.over90;

    return CreditSummary(
      totalOutstanding: totalOutstanding,
      overdueAmount: overdueAmount,
      collectedThisMonth: paymentsThisMonth,
      creditCustomersCount: creditCustomersCount,
    );
  }
}

// ==================== Helper Classes ====================

class CustomerWithCredit {
  final Customer customer;

  CustomerWithCredit({required this.customer});

  String get id => customer.id;
  String get name => customer.name;
  String? get phone => customer.phone;
  double get creditBalance => customer.creditBalance;
  double get creditLimit => customer.creditLimit;
  double get availableCredit => customer.creditLimit - customer.creditBalance;
  bool get isOverLimit => customer.creditBalance > customer.creditLimit;
}

class OutstandingSale {
  final Sale sale;
  final double paidAmount;
  final double outstandingAmount;
  final int daysSinceSale;

  OutstandingSale({
    required this.sale,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.daysSinceSale,
  });

  String get invoiceNumber => sale.invoiceNumber;
  DateTime get saleDate => sale.saleDate;
  double get totalAmount => sale.totalAmount;

  String get agingBucket {
    if (daysSinceSale <= 30) return 'Current';
    if (daysSinceSale <= 60) return '31-60 days';
    if (daysSinceSale <= 90) return '61-90 days';
    return '90+ days';
  }
}

class AgingSummary {
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double over90;
  final double total;

  AgingSummary({
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.over90,
    required this.total,
  });
}

class CustomerAging {
  final Customer customer;
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double over90;
  final double total;
  final int oldestInvoiceDays;

  CustomerAging({
    required this.customer,
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.over90,
    required this.total,
    required this.oldestInvoiceDays,
  });

  String get customerName => customer.name;
  String? get customerPhone => customer.phone;
}

class CreditTransactionWithDetails {
  final CreditTransaction transaction;
  final Sale? relatedSale;

  CreditTransactionWithDetails({
    required this.transaction,
    this.relatedSale,
  });

  CreditTransactionType get type =>
      CreditTransactionTypeExtension.fromString(transaction.transactionType);

  bool get isDebit => type == CreditTransactionType.sale;
  bool get isCredit => type == CreditTransactionType.payment;
}

class CreditSummary {
  final double totalOutstanding;
  final double overdueAmount;
  final double collectedThisMonth;
  final int creditCustomersCount;

  CreditSummary({
    required this.totalOutstanding,
    required this.overdueAmount,
    required this.collectedThisMonth,
    required this.creditCustomersCount,
  });
}
