import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/sale.dart' as entity;
import '../../presentation/providers/core/database_provider.dart';
import '../../presentation/providers/core/settings_provider.dart';
import 'receipt_printer.dart';

/// Prints (or reprints) the A4 invoice for a saved sale.
/// Used by the POS after checkout and by Sales History for reprints.
/// Throws if the sale can't be found.
Future<void> printSaleInvoice(
  WidgetRef ref,
  String saleId, {
  String? customerName,
}) async {
  final companySettings = await ref.read(companySettingsProvider.future);
  final db = ref.read(databaseProvider);

  final saleDetail = await db.salesDao.getSaleDetail(saleId);
  if (saleDetail == null) {
    throw Exception('Sale not found');
  }

  final entitySale = entity.Sale(
    id: saleDetail.sale.id,
    invoiceNumber: saleDetail.sale.invoiceNumber,
    customerId: saleDetail.sale.customerId,
    saleDate: saleDetail.sale.saleDate,
    subtotal: saleDetail.sale.subtotal,
    discountAmount: saleDetail.sale.discountAmount,
    taxAmount: saleDetail.sale.taxAmount,
    totalAmount: saleDetail.sale.totalAmount,
    paidAmount: saleDetail.sale.paidAmount,
    totalCost: saleDetail.sale.totalCost,
    grossProfit: saleDetail.sale.grossProfit,
    isCredit: saleDetail.sale.isCredit,
    status: saleDetail.sale.status,
    notes: saleDetail.sale.notes,
    createdBy: saleDetail.sale.createdBy,
    createdAt: saleDetail.sale.createdAt,
    updatedAt: saleDetail.sale.updatedAt,
    items: saleDetail.items.map((item) => entity.SaleItem(
      id: item.item.id,
      saleId: item.item.saleId,
      productId: item.item.productId,
      productName: item.productName,
      productCode: item.productCode,
      quantity: item.item.quantity,
      unitPrice: item.item.unitPrice,
      unitCost: item.item.unitCost,
      discountAmount: item.item.discountAmount,
      totalPrice: item.item.totalPrice,
      totalCost: item.item.totalCost,
      profit: item.item.profit,
      serials: item.serials.map((s) => entity.SaleSerial(
        id: s.id,
        saleItemId: s.saleItemId,
        serialNumberId: s.serialNumberId,
        serialNumber: s.serialNumber,
        unitCost: s.unitCost,
      )).toList(),
    )).toList(),
  );

  await ReceiptPrinter.printA4Invoice(
    sale: entitySale,
    companyName: companySettings.name.isNotEmpty ? companySettings.name : 'M-TRONIC',
    companyAddress: companySettings.address.isNotEmpty ? companySettings.address : '',
    companyPhone: companySettings.phone.isNotEmpty ? companySettings.phone : '',
    customerName: customerName ?? saleDetail.customer?.name,
    customerPhone: saleDetail.customer?.phone,
    customerAddress: saleDetail.customer?.address,
    customerEmail: saleDetail.customer?.email,
    bankName: companySettings.bankName,
    accountName: companySettings.bankAccountName,
    accountNumber: companySettings.bankAccountNumber,
    bankBranch: companySettings.bankBranch,
  );
}
