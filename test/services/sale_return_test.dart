import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cp_pos/core/enums/payment_method.dart';
import 'package:cp_pos/data/local/daos/sales_dao.dart';
import 'package:cp_pos/data/local/database/app_database.dart';

void main() {
  test('returning a sale restores stock, refunds, and drops it from reports', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(ProductsCompanion.insert(id: 'p1', code: 'P1', name: 'Mouse'));
    await db.into(db.inventory).insert(InventoryCompanion.insert(
        id: 'i1', productId: 'p1', quantityOnHand: const Value(10), totalCost: const Value(1000)));

    final sale = await db.salesDao.createSale(
      cartItems: [CartItem(productId: 'p1', productName: 'Mouse', quantity: 3, unitPrice: 250, unitCost: 100)],
      payments: [PaymentEntry(method: PaymentMethod.cash, amount: 750)],
    );
    var inv = await db.inventoryDao.getInventoryByProductId('p1');
    expect(inv!.quantityOnHand, 7);

    final today = DateTime.now();
    final before = await db.salesDao.getSalesSummary(today.subtract(const Duration(days: 1)), today);
    expect(before.totalRevenue, 750);

    final refund = await db.salesDao.returnSale(
        saleId: sale.id, refundMethod: PaymentMethod.cash, reason: 'Faulty');
    expect(refund, 750);

    inv = await db.inventoryDao.getInventoryByProductId('p1');
    expect(inv!.quantityOnHand, 10);
    expect(inv.totalCost, 1000);

    final after = (await db.salesDao.getSaleById(sale.id))!;
    expect(after.status, 'RETURNED');
    expect(after.notes, contains('Faulty'));

    final pays = await db.salesDao.getSalePayments(sale.id);
    expect(pays.map((p) => p.amount).fold<double>(0, (a, b) => a + b), 0);

    final summary = await db.salesDao.getSalesSummary(today.subtract(const Duration(days: 1)), today);
    expect(summary.totalRevenue, 0);
    expect(summary.totalSales, 0);

    // Can't return twice
    expect(await db.salesDao.getReturnBlocker(sale.id), isNotNull);
    await db.close();
  });
}
