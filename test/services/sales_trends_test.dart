import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cp_pos/core/enums/payment_method.dart';
import 'package:cp_pos/data/local/daos/sales_dao.dart';
import 'package:cp_pos/data/local/daos/sales_trends.dart';
import 'package:cp_pos/data/local/database/app_database.dart';

void main() {
  test('trend, top products and payment mix ignore returned sales', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(ProductsCompanion.insert(id: 'p1', code: 'P1', name: 'Mouse'));
    await db.into(db.products).insert(ProductsCompanion.insert(id: 'p2', code: 'P2', name: 'SSD'));

    final s1 = await db.salesDao.createSale(
      cartItems: [CartItem(productId: 'p1', productName: 'Mouse', quantity: 2, unitPrice: 500, unitCost: 300)],
      payments: [PaymentEntry(method: PaymentMethod.cash, amount: 1000)],
    );
    await db.salesDao.createSale(
      cartItems: [
        CartItem(productId: 'p2', productName: 'SSD', quantity: 1, unitPrice: 8000, unitCost: 6000),
        CartItem(productId: serviceChargeId('Installation'), productName: 'Installation', quantity: 1, unitPrice: 1500, unitCost: 0),
      ],
      payments: [PaymentEntry(method: PaymentMethod.card, amount: 9000)],
      creditAmount: 500,
    );
    final returned = await db.salesDao.createSale(
      cartItems: [CartItem(productId: 'p2', productName: 'SSD', quantity: 1, unitPrice: 8000, unitCost: 6000)],
      payments: [PaymentEntry(method: PaymentMethod.cash, amount: 8000)],
    );
    await db.salesDao.returnSale(saleId: returned.id, refundMethod: PaymentMethod.cash);
    expect(s1.status, 'COMPLETED');

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 6);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final trend = await db.salesDao.revenueTrend(start, end, monthly: false);
    expect(trend.length, 7);
    expect(trend.last.revenue, 1000 + 9500);
    expect(trend.last.count, 2);
    expect(trend.first.revenue, 0);

    final top = await db.salesDao.topProducts(start, end);
    expect(top.map((t) => t.name).toList(), ['SSD', 'Installation', 'Mouse']);
    expect(top.first.revenue, 8000);

    final mix = {for (final m in await db.salesDao.paymentMix(start, end)) m.method: m.amount};
    expect(mix['CARD'], 9000);
    expect(mix['CASH'], 1000);
    expect(mix['CREDIT (UNPAID)'], 500);
    await db.close();
  });
}
