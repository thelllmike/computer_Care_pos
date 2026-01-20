import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/sale.dart';

class ReceiptPrinter {
  /// Prints a thermal receipt (80mm)
  static Future<bool> printThermalReceipt({
    required Sale sale,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? customerName,
  }) async {
    final pdf = pw.Document();

    // 80mm = ~283 points at 72 DPI
    const receiptWidth = 80 * 2.83; // ~227 points

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(receiptWidth, double.infinity),
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                companyName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Tel: $companyPhone', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),

              // Invoice info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(sale.invoiceNumber, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    Formatters.dateTime(sale.saleDate),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              if (customerName != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(customerName, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // Items
              pw.ListView.builder(
                itemCount: sale.items.length,
                itemBuilder: (context, index) {
                  final item = sale.items[index];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Product ${item.productId}', // In real app, use product name
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${item.quantity} x ${Formatters.currency(item.unitPrice)}',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                            pw.Text(
                              Formatters.currency(item.totalPrice),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              pw.Divider(thickness: 0.5),

              // Totals
              _buildTotalRow('Subtotal', sale.subtotal),
              if (sale.discountAmount > 0)
                _buildTotalRow('Discount', -sale.discountAmount),
              if (sale.taxAmount > 0)
                _buildTotalRow('Tax', sale.taxAmount),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    Formatters.currency(sale.totalAmount),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              _buildTotalRow('Paid', sale.paidAmount),
              if (sale.outstandingAmount > 0)
                _buildTotalRow('Balance Due', sale.outstandingAmount),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 0.5),

              // Footer
              pw.Text(
                'Thank you for your purchase!',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Goods sold are not refundable',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    return await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Receipt_${sale.invoiceNumber}',
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(Formatters.currency(amount), style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  /// Prints an A4 invoice
  static Future<bool> printA4Invoice({
    required Sale sale,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? customerName,
    String? customerAddress,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(companyAddress),
                      pw.Text('Tel: $companyPhone'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        sale.invoiceNumber,
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Invoice details and customer info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(customerName ?? 'Walk-in Customer'),
                        if (customerAddress != null) pw.Text(customerAddress),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${Formatters.date(sale.saleDate)}'),
                      pw.SizedBox(height: 4),
                      if (sale.isCredit)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.orange100,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'CREDIT SALE',
                            style: const pw.TextStyle(color: PdfColors.orange900),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableCell('Item', isHeader: true),
                      _tableCell('Qty', isHeader: true),
                      _tableCell('Unit Price', isHeader: true),
                      _tableCell('Total', isHeader: true),
                    ],
                  ),
                  // Item rows
                  ...sale.items.map((item) => pw.TableRow(
                        children: [
                          _tableCell('Product ${item.productId}'),
                          _tableCell(item.quantity.toString()),
                          _tableCell(Formatters.currency(item.unitPrice)),
                          _tableCell(Formatters.currency(item.totalPrice)),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _invoiceTotalRow('Subtotal', sale.subtotal),
                        if (sale.discountAmount > 0)
                          _invoiceTotalRow('Discount', -sale.discountAmount),
                        if (sale.taxAmount > 0)
                          _invoiceTotalRow('Tax', sale.taxAmount),
                        pw.Divider(),
                        _invoiceTotalRow('Total', sale.totalAmount, isTotal: true),
                        _invoiceTotalRow('Paid', sale.paidAmount),
                        if (sale.outstandingAmount > 0)
                          _invoiceTotalRow('Balance Due', sale.outstandingAmount,
                              highlight: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Generated by ${AppConstants.appName}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Invoice_${sale.invoiceNumber}',
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  static pw.Widget _invoiceTotalRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool highlight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : null,
              fontSize: isTotal ? 14 : 12,
            ),
          ),
          pw.Text(
            Formatters.currency(amount),
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : null,
              fontSize: isTotal ? 14 : 12,
              color: highlight ? PdfColors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}
