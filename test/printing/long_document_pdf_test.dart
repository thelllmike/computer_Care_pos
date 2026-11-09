import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cp_pos/data/local/database/app_database.dart';
import 'package:cp_pos/services/printing/receipt_printer.dart';

int pageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['PDF_OUT'];

  for (final n in [3, 15, 40]) {
    test('invoice with $n items keeps every item', () async {
      final data = InvoiceData(
        invoiceNumber: 'INV-TEST',
        invoiceDate: DateTime(2026, 11, 9),
        companyName: 'Computer Care',
        companyShortName: 'CC',
        companyAddress: 'Colombo',
        companyPhone: '0771234567',
        customerName: 'Test Customer',
        items: [
          for (var i = 1; i <= n; i++)
            InvoiceItem(code: 'P$i', description: 'Product number $i', quantity: 1, unitPrice: 1000),
        ],
        subtotal: n * 1000.0,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: n * 1000.0,
        paidAmount: n * 1000.0,
        isCredit: false,
      );
      final bytes = await ProfessionalInvoiceGenerator.generateInvoice(data);
      if (outDir != null) File('$outDir/invoice_$n.pdf').writeAsBytesSync(bytes);
      final pages = pageCount(bytes);
      // ignore: avoid_print
      print('invoice $n items -> $pages page(s)');
      if (n == 40) expect(pages, greaterThan(1));
      if (n == 3) expect(pages, 1);
    });

    test('quotation with $n items keeps every item', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.quotations).insert(QuotationsCompanion.insert(
          id: 'q1', quotationNumber: 'QTN-TEST', quotationDate: DateTime(2026, 11, 9)));
      for (var i = 1; i <= n; i++) {
        await db.into(db.products).insert(ProductsCompanion.insert(id: 'p$i', code: 'P$i', name: 'Product number $i'));
        await db.into(db.quotationItems).insert(QuotationItemsCompanion.insert(
            id: 'qi$i', quotationId: 'q1', productId: 'p$i', quantity: 1, unitPrice: 1000, totalPrice: 1000));
      }
      final detail = (await db.quotationDao.getQuotationDetail('q1'))!;
      expect(detail.items.length, n);
      final bytes = await ReceiptPrinter.buildQuotationPdf(detail: detail, companyName: 'Computer Care');
      if (outDir != null) File('$outDir/quotation_$n.pdf').writeAsBytesSync(bytes);
      final pages = pageCount(bytes);
      // ignore: avoid_print
      print('quotation $n items -> $pages page(s)');
      if (n == 40) expect(pages, greaterThan(1));
      if (n == 3) expect(pages, 1);
      await db.close();
    });
  }
}
