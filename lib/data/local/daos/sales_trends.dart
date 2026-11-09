import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'sales_dao.dart';

/// One time bucket (a day or a month) of sales.
class TrendPoint {
  final DateTime bucket;
  double revenue = 0;
  double profit = 0;
  int count = 0;
  TrendPoint(this.bucket);
}

class ProductTotal {
  final String name;
  int quantity = 0;
  double revenue = 0;
  ProductTotal(this.name);
}

class MethodTotal {
  final String method;
  final double amount;
  const MethodTotal(this.method, this.amount);
}

/// Aggregations for the Trends & Charts report. Returned sales are excluded.
extension SalesTrends on SalesDao {
  Future<List<Sale>> _salesIn(DateTime start, DateTime end) {
    return (select(sales)
          ..where((t) =>
              t.saleDate.isBiggerOrEqualValue(start) &
              t.saleDate.isSmallerOrEqualValue(end) &
              t.status.equals('RETURNED').not()))
        .get();
  }

  static DateTime _bucketOf(DateTime d, bool monthly) =>
      monthly ? DateTime(d.year, d.month) : DateTime(d.year, d.month, d.day);

  /// Revenue / profit / count per day (or per month), with empty buckets
  /// filled in as zero so the line is continuous.
  Future<List<TrendPoint>> revenueTrend(DateTime start, DateTime end,
      {required bool monthly}) async {
    final points = <DateTime, TrendPoint>{};
    var cursor = _bucketOf(start, monthly);
    final last = _bucketOf(end, monthly);
    while (!cursor.isAfter(last)) {
      points[cursor] = TrendPoint(cursor);
      cursor = monthly
          ? DateTime(cursor.year, cursor.month + 1)
          : DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    for (final s in await _salesIn(start, end)) {
      final p = points[_bucketOf(s.saleDate, monthly)];
      if (p == null) continue;
      p.revenue += s.totalAmount;
      p.profit += s.grossProfit;
      p.count++;
    }
    return points.values.toList();
  }

  /// Best-selling products (and service charges) by revenue.
  Future<List<ProductTotal>> topProducts(DateTime start, DateTime end,
      {int limit = 8}) async {
    final ids = (await _salesIn(start, end)).map((s) => s.id).toList();
    if (ids.isEmpty) return [];
    final rows = await (select(saleItems).join([
      leftOuterJoin(products, products.id.equalsExp(saleItems.productId)),
    ])
          ..where(saleItems.saleId.isIn(ids)))
        .get();

    final totals = <String, ProductTotal>{};
    for (final row in rows) {
      final item = row.readTable(saleItems);
      final product = row.readTableOrNull(products);
      final name = product?.name ??
          (item.productId == 'SERVICE_LABOR'
              ? 'Repair labour'
              : isServiceChargeId(item.productId)
                  ? serviceChargeDescription(item.productId)
                  : 'Unknown product');
      final t = totals.putIfAbsent(item.productId, () => ProductTotal(name));
      t.quantity += item.quantity;
      t.revenue += item.totalPrice;
    }
    final list = totals.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }

  /// Money received by payment method, plus unpaid credit.
  Future<List<MethodTotal>> paymentMix(DateTime start, DateTime end) async {
    final saleList = await _salesIn(start, end);
    if (saleList.isEmpty) return [];
    final ids = saleList.map((s) => s.id).toList();
    final pays = await (select(payments)
          ..where((p) => p.saleId.isIn(ids) & p.amount.isBiggerThanValue(0)))
        .get();

    final byMethod = <String, double>{};
    double paidViaPayments = 0;
    for (final p in pays) {
      byMethod[p.paymentMethod] = (byMethod[p.paymentMethod] ?? 0) + p.amount;
      paidViaPayments += p.amount;
    }
    // Sales paid in full without separate payment rows (e.g. quick cash sales)
    final totalPaid = saleList.fold<double>(0, (a, s) => a + s.paidAmount);
    final untracked = totalPaid - paidViaPayments;
    if (untracked > 0.5) byMethod['CASH'] = (byMethod['CASH'] ?? 0) + untracked;

    final unpaid = saleList.fold<double>(
        0, (a, s) => a + (s.totalAmount - s.paidAmount).clamp(0, double.infinity));
    if (unpaid > 0.5) byMethod['CREDIT (UNPAID)'] = unpaid;

    final list = byMethod.entries.map((e) => MethodTotal(e.key, e.value)).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }
}
