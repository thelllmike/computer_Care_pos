import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/daos/quotation_dao.dart';
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
                          item.productName ?? item.productId,
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
              pw.SizedBox(height: 8),
              pw.Text(
                AppConstants.poweredBy,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
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
                          _tableCell(item.productName ?? item.productId),
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
                  AppConstants.poweredBy,
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

  // ==================== Quotation Printing ====================

  /// Prints an A4 quotation
  static Future<bool> printQuotation({
    required QuotationDetail detail,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? companyEmail,
  }) async {
    final pdf = pw.Document();
    final quotation = detail.quotation;
    final customer = detail.customer;
    final items = detail.items;

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
                      if (companyEmail != null)
                        pw.Text('Email: $companyEmail'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'QUOTATION',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                      pw.Text(
                        quotation.quotationNumber,
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Quotation details and customer info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(customer?.name ?? 'Valued Customer'),
                        if (customer?.address != null) pw.Text(customer!.address!),
                        if (customer?.phone != null) pw.Text('Tel: ${customer!.phone}'),
                        if (customer?.email != null) pw.Text('Email: ${customer!.email}'),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${Formatters.date(quotation.createdAt)}'),
                      pw.SizedBox(height: 4),
                      if (quotation.validUntil != null)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'Valid Until: ${Formatters.date(quotation.validUntil!)}',
                            style: const pw.TextStyle(color: PdfColors.blue900),
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
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _tableCell('#', isHeader: true),
                      _tableCell('Description', isHeader: true),
                      _tableCell('Qty', isHeader: true),
                      _tableCell('Unit Price', isHeader: true),
                      _tableCell('Discount', isHeader: true),
                      _tableCell('Total', isHeader: true),
                    ],
                  ),
                  // Item rows
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    final lineTotal = (item.item.unitPrice * item.item.quantity) - item.item.discountAmount;
                    return pw.TableRow(
                      children: [
                        _tableCell(idx.toString()),
                        _tableCell('${item.product.name}\n${item.product.code}'),
                        _tableCell(item.item.quantity.toString()),
                        _tableCell(Formatters.currency(item.item.unitPrice)),
                        _tableCell(item.item.discountAmount > 0
                            ? Formatters.currency(item.item.discountAmount)
                            : '-'),
                        _tableCell(Formatters.currency(lineTotal)),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _quotationTotalRow('Subtotal', quotation.subtotal),
                        if (quotation.discountAmount > 0)
                          _quotationTotalRow('Discount', -quotation.discountAmount),
                        if (quotation.taxAmount > 0)
                          _quotationTotalRow('Tax', quotation.taxAmount),
                        pw.Divider(color: PdfColors.blue300),
                        _quotationTotalRow('Total', quotation.totalAmount, isTotal: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Notes
              if (quotation.notes != null && quotation.notes!.isNotEmpty) ...[
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(quotation.notes!),
                ),
                pw.SizedBox(height: 20),
              ],

              // Terms and conditions
              pw.Text(
                'Terms & Conditions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '1. Prices are valid until the date mentioned above.\n'
                '2. Prices are subject to change without prior notice.\n'
                '3. This quotation does not constitute a binding contract.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your interest in our products!',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  AppConstants.poweredBy,
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
      name: 'Quotation_${quotation.quotationNumber}',
    );
  }

  static pw.Widget _quotationTotalRow(
    String label,
    double amount, {
    bool isTotal = false,
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
              color: isTotal ? PdfColors.blue700 : null,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WhatsApp Sharing ====================

  /// Generates quotation PDF and shares directly to WhatsApp
  /// Returns result with file path and status
  static Future<WhatsAppShareResult> shareQuotationToWhatsApp({
    required QuotationDetail detail,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? companyEmail,
    String? customerPhone,
  }) async {
    try {
      // Generate PDF bytes
      final pdfBytes = await _generateQuotationPdfBytes(
        detail: detail,
        companyName: companyName,
        companyAddress: companyAddress,
        companyPhone: companyPhone,
        companyEmail: companyEmail,
      );

      // Save to Documents folder for easy access
      final docsDir = await getApplicationDocumentsDirectory();
      final quotationsDir = Directory('${docsDir.path}/Quotations');
      if (!await quotationsDir.exists()) {
        await quotationsDir.create(recursive: true);
      }

      final fileName = 'Quotation_${detail.quotation.quotationNumber}.pdf';
      final filePath = '${quotationsDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Format phone number for WhatsApp (remove spaces, dashes, and ensure country code)
      String? formattedPhone;
      if (customerPhone != null && customerPhone.isNotEmpty) {
        formattedPhone = customerPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        // If doesn't start with +, assume Sri Lanka (+94) and handle leading 0
        if (!formattedPhone.startsWith('+')) {
          if (formattedPhone.startsWith('0')) {
            formattedPhone = '94${formattedPhone.substring(1)}';
          } else if (!formattedPhone.startsWith('94')) {
            formattedPhone = '94$formattedPhone';
          }
        } else {
          formattedPhone = formattedPhone.substring(1); // Remove + for wa.me
        }
      }

      // Create message text (use simple text without special currency symbols)
      final totalFormatted = detail.quotation.totalAmount.toStringAsFixed(2);
      final message = 'Hello! Please find attached the quotation '
          '${detail.quotation.quotationNumber} for Rs. $totalFormatted. '
          '${detail.quotation.validUntil != null ? 'Valid until ${Formatters.date(detail.quotation.validUntil!)}. ' : ''}'
          'Thank you for your interest!';

      // First open WhatsApp with the customer's number (so it's ready)
      bool whatsAppOpened = false;
      if (formattedPhone != null) {
        final whatsappUrl = Uri.parse(
          'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}',
        );
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          whatsAppOpened = true;
        }
      }

      // Small delay to let WhatsApp open first
      await Future.delayed(const Duration(milliseconds: 500));

      // Use native share dialog to share the PDF directly
      // On Windows, this opens the Share UI where user can select WhatsApp
      final xFile = XFile(filePath);
      final shareResult = await Share.shareXFiles(
        [xFile],
        text: message,
        subject: 'Quotation ${detail.quotation.quotationNumber}',
      );

      return WhatsAppShareResult(
        success: true,
        filePath: filePath,
        whatsAppOpened: whatsAppOpened,
        phoneNumber: formattedPhone,
        shareStatus: shareResult.status.name,
      );
    } catch (e) {
      return WhatsAppShareResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Generates quotation PDF bytes (A4 format) without showing print dialog
  static Future<List<int>> _generateQuotationPdfBytes({
    required QuotationDetail detail,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? companyEmail,
  }) async {
    final pdf = pw.Document();
    final quotation = detail.quotation;
    final customer = detail.customer;
    final items = detail.items;

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
                      if (companyEmail != null) pw.Text('Email: $companyEmail'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'QUOTATION',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                      pw.Text(
                        quotation.quotationNumber,
                        style: const pw.TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Quotation details and customer info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('To:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(customer?.name ?? 'Valued Customer'),
                        if (customer?.address != null) pw.Text(customer!.address!),
                        if (customer?.phone != null) pw.Text('Tel: ${customer!.phone}'),
                        if (customer?.email != null) pw.Text('Email: ${customer!.email}'),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${Formatters.date(quotation.createdAt)}'),
                      pw.SizedBox(height: 4),
                      if (quotation.validUntil != null)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'Valid Until: ${Formatters.date(quotation.validUntil!)}',
                            style: const pw.TextStyle(color: PdfColors.blue900),
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
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _tableCell('#', isHeader: true),
                      _tableCell('Description', isHeader: true),
                      _tableCell('Qty', isHeader: true),
                      _tableCell('Unit Price', isHeader: true),
                      _tableCell('Discount', isHeader: true),
                      _tableCell('Total', isHeader: true),
                    ],
                  ),
                  // Item rows
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    final lineTotal =
                        (item.item.unitPrice * item.item.quantity) - item.item.discountAmount;
                    return pw.TableRow(
                      children: [
                        _tableCell(idx.toString()),
                        _tableCell('${item.product.name}\n${item.product.code}'),
                        _tableCell(item.item.quantity.toString()),
                        _tableCell(Formatters.currency(item.item.unitPrice)),
                        _tableCell(item.item.discountAmount > 0
                            ? Formatters.currency(item.item.discountAmount)
                            : '-'),
                        _tableCell(Formatters.currency(lineTotal)),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _quotationTotalRow('Subtotal', quotation.subtotal),
                        if (quotation.discountAmount > 0)
                          _quotationTotalRow('Discount', -quotation.discountAmount),
                        if (quotation.taxAmount > 0)
                          _quotationTotalRow('Tax', quotation.taxAmount),
                        pw.Divider(color: PdfColors.blue300),
                        _quotationTotalRow('Total', quotation.totalAmount, isTotal: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Notes
              if (quotation.notes != null && quotation.notes!.isNotEmpty) ...[
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(quotation.notes!),
                ),
                pw.SizedBox(height: 20),
              ],

              // Terms and conditions
              pw.Text(
                'Terms & Conditions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '1. Prices are valid until the date mentioned above.\n'
                '2. Prices are subject to change without prior notice.\n'
                '3. This quotation does not constitute a binding contract.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your interest in our products!',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  AppConstants.poweredBy,
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

    return pdf.save();
  }
}

/// Result of WhatsApp sharing operation
class WhatsAppShareResult {
  final bool success;
  final String? filePath;
  final bool whatsAppOpened;
  final String? phoneNumber;
  final String? error;
  final String? shareStatus;

  WhatsAppShareResult({
    required this.success,
    this.filePath,
    this.whatsAppOpened = false,
    this.phoneNumber,
    this.error,
    this.shareStatus,
  });
}
