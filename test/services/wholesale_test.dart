import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cp_pos/core/enums/product_type.dart';
import 'package:cp_pos/data/local/database/app_database.dart';
import 'package:cp_pos/presentation/providers/sales/sales_provider.dart';

void main() {
  test('wholesale price is stored on products', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final p = await db.productDao.insertProduct(
      code: 'P1', name: 'Mouse', productType: ProductType.accessory,
      requiresSerial: false, sellingPrice: 1200, wholesalePrice: 950,
    );
    expect(p.wholesalePrice, 950);
    await db.productDao.updateProduct(id: p.id, wholesalePrice: 900);
    expect((await db.productDao.getProductById(p.id))!.wholesalePrice, 900);
    await db.close();
  });

  test('wholesale mode re-prices cart lines and back', () {
    final cart = CartNotifier();
    cart.addProduct(productId: 'p1', productName: 'Mouse', productCode: 'P1',
        unitPrice: 1200, unitCost: 700, trackSerials: false);
    cart.addProduct(productId: 'SERVICE:Install', productName: 'Install', productCode: 'SERVICE',
        unitPrice: 500, unitCost: 0, trackSerials: false);

    double? priceFor(String id, bool wholesale) =>
        id == 'p1' ? (wholesale ? 950 : 1200) : null;

    cart.setWholesale(true, priceFor);
    expect(cart.state.isWholesale, true);
    expect(cart.state.items.map((i) => i.unitPrice).toList(), [950, 500]);

    cart.setWholesale(false, priceFor);
    expect(cart.state.items.map((i) => i.unitPrice).toList(), [1200, 500]);
  });
}
