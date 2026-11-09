import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cp_pos/core/enums/payment_method.dart';
import 'package:cp_pos/data/local/daos/sales_dao.dart';
import 'package:cp_pos/data/local/database/app_database.dart';

void main() {
  test('service charge sells without stock and shows as labour income', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.products).insert(ProductsCompanion.insert(id: 'p1', code: 'P1', name: 'Mouse'));
    await db.into(db.inventory).insert(InventoryCompanion.insert(
        id: 'i1', productId: 'p1', quantityOnHand: const Value(5), totalCost: const Value(500)));

    final sale = await db.salesDao.createSale(
      cartItems: [
        CartItem(productId: 'p1', productName: 'Mouse', quantity: 1, unitPrice: 250, unitCost: 100),
        CartItem(productId: serviceChargeId('OS installation'), productName: 'OS installation',
            quantity: 1, unitPrice: 1500, unitCost: 0),
      ],
      payments: [PaymentEntry(method: PaymentMethod.cash, amount: 1750)],
    );

    final detail = (await db.salesDao.getSaleDetail(sale.id))!;
    final names = detail.items.map((i) => i.productName).toList();
    expect(names, containsAll(['Mouse', 'OS installation']));
    final svc = detail.items.firstWhere((i) => i.productName == 'OS installation');
    expect(svc.productCode, 'SERVICE');
    expect(svc.item.profit, 1500);

    final today = DateTime.now();
    final summary = await db.salesDao.getSalesSummary(today.subtract(const Duration(days: 1)), today);
    expect(summary.totalRevenue, 1750);
    expect(summary.laborIncome, 1500);

    expect((await db.inventoryDao.getInventoryByProductId('p1'))!.quantityOnHand, 4);

    // Sales with service charges can still be returned
    expect(await db.salesDao.getReturnBlocker(sale.id), null);
    await db.salesDao.returnSale(saleId: sale.id, refundMethod: PaymentMethod.cash);
    expect((await db.inventoryDao.getInventoryByProductId('p1'))!.quantityOnHand, 5);
    await db.close();
  });
}
