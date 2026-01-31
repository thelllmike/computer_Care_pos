import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/daos/quotation_dao.dart';
import '../../data/local/database/app_database.dart' hide Sale, SaleItem;
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

  /// Prints an A4 invoice with professional MMP-style dark theme
  /// Uses ProfessionalInvoiceGenerator for full-featured invoice
  static Future<bool> printA4Invoice({
    required Sale sale,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? customerEmail,
    String? companyEmail,
    String? companyWebsite,
    String? companyWhatsApp,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    final invoiceData = await ProfessionalInvoiceGenerator.fromSale(
      sale: sale,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyWebsite: companyWebsite,
      companyWhatsApp: companyWhatsApp,
      customerName: customerName,
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );

    return await ProfessionalInvoiceGenerator.printInvoice(invoiceData);
  }

  /// Legacy simple A4 invoice (kept for backward compatibility)
  static Future<bool> printSimpleA4Invoice({
    required Sale sale,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            color: _darkBackground,
            child: pw.Column(
              children: [
                // Header with blue accent
                _buildDocumentHeader(companyName, sale.invoiceNumber, sale.saleDate, 'INVOICE'),

                // Content
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Customer info
                        _buildSimpleInvoiceClientInfo(customerName, customerAddress, customerPhone, sale.isCredit),
                        pw.SizedBox(height: 20),

                        // Items table
                        _buildSimpleInvoiceTable(sale.items),
                        pw.SizedBox(height: 20),

                        // Summary
                        _buildSimpleInvoiceSummary(sale),

                        pw.Spacer(),

                        // Footer
                        _buildSimpleInvoiceFooter(companyAddress, companyPhone),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Invoice_${sale.invoiceNumber}',
    );
  }

  static pw.Widget _buildSimpleInvoiceClientInfo(String? customerName, String? customerAddress, String? customerPhone, bool isCredit) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: _primaryBlue,
              child: pw.Text(
                'BILL TO :',
                style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              customerName ?? 'Walk-in Customer',
              style: pw.TextStyle(color: _white, fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (customerAddress != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(customerAddress, style: pw.TextStyle(color: _white, fontSize: 10)),
            ],
            if (customerPhone != null) ...[
              pw.SizedBox(height: 4),
              pw.Text('Tel: $customerPhone', style: pw.TextStyle(color: _white, fontSize: 10)),
            ],
          ],
        ),
        if (isCredit)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'CREDIT SALE',
              style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildSimpleInvoiceTable(List<SaleItem> items) {
    return pw.Table(
      border: null,
      columnWidths: {
        0: const pw.FixedColumnWidth(25),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(35),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(80),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primaryBlue),
          children: [
            _darkTableHeader('#'),
            _darkTableHeader('DESCRIPTION'),
            _darkTableHeader('QTY'),
            _darkTableHeader('UNIT PRICE'),
            _darkTableHeader('TOTAL'),
          ],
        ),
        // Data rows
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          final isEven = idx % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? _lightGrey : PdfColors.white,
            ),
            children: [
              _darkTableCell(idx.toString()),
              _darkTableCell(item.productName ?? item.productId),
              _darkTableCell(item.quantity.toString()),
              _darkTableCell('Rs. ${item.unitPrice.toStringAsFixed(2)}'),
              _darkTableCell('Rs. ${item.totalPrice.toStringAsFixed(2)}'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSimpleInvoiceSummary(Sale sale) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'SUB TOTAL : Rs. ${sale.subtotal.toStringAsFixed(2)}',
              style: pw.TextStyle(color: _white, fontSize: 11),
            ),
            if (sale.discountAmount > 0) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'DISCOUNT : Rs. ${sale.discountAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(color: _white, fontSize: 11),
              ),
            ],
            if (sale.taxAmount > 0) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'TAX : Rs. ${sale.taxAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(color: _white, fontSize: 11),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: _primaryBlue,
              child: pw.Text(
                'TOTAL : Rs. ${sale.totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'PAID : Rs. ${sale.paidAmount.toStringAsFixed(2)}',
              style: pw.TextStyle(color: _white, fontSize: 11),
            ),
            if (sale.outstandingAmount > 0) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: PdfColors.orange,
                child: pw.Text(
                  'BALANCE DUE : Rs. ${sale.outstandingAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    color: _white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSimpleInvoiceFooter(String companyAddress, String companyPhone) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Left side - Thank you message
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'THANK YOU FOR YOUR BUSINESS!',
              style: pw.TextStyle(
                color: _white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Goods sold are not refundable without receipt',
              style: pw.TextStyle(color: _white, fontSize: 9),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              companyAddress,
              style: pw.TextStyle(color: _white, fontSize: 8),
            ),
            pw.Text(
              'Tel: $companyPhone',
              style: pw.TextStyle(color: _white, fontSize: 8),
            ),
          ],
        ),
        // Right side - Notes
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'WARRANTY INFO',
              style: pw.TextStyle(color: _primaryBlue, fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Keep this invoice for',
              style: pw.TextStyle(color: _white, fontSize: 9),
            ),
            pw.Text(
              'warranty claims',
              style: pw.TextStyle(color: _white, fontSize: 9),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              AppConstants.poweredBy,
              style: pw.TextStyle(color: _white, fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== Quotation Printing ====================

  // Design colors
  static const _primaryBlue = PdfColor.fromInt(0xFF0081FF);
  static const _darkBackground = PdfColor.fromInt(0xFF1E252B);
  static const _white = PdfColors.white;
  static const _lightGrey = PdfColor.fromInt(0xFFF5F5F5);

  /// Prints an A4 quotation with dark professional theme
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

    // Load logo image before building the page
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            color: _darkBackground,
            child: pw.Column(
              children: [
                // Header with blue accent and logo
                _buildDocumentHeader(companyName, quotation.quotationNumber, quotation.createdAt, 'QUOTATION', logoImage: logoImage),

                // Content
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Client info
                        _buildClientInfo(customer),
                        pw.SizedBox(height: 24),

                        // Items table
                        _buildQuotationTable(items),
                        pw.SizedBox(height: 6),

                        // Summary (includes its own top divider)
                        _buildQuotationSummary(quotation),

                        pw.Spacer(),

                        // Footer (includes its own top divider)
                        _buildQuotationFooter(companyAddress, companyPhone, quotation.validUntil),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Quotation_${quotation.quotationNumber}',
    );
  }

  static pw.Widget _buildDocumentHeader(String companyName, String documentNumber, DateTime date, String documentType, {pw.MemoryImage? logoImage}) {
    // Extract company short name (first letters or abbreviation)
    final words = companyName.split(' ');
    final shortName = words.length > 1
        ? words.map((w) => w.isNotEmpty ? w[0] : '').join()
        : (companyName.length > 3 ? companyName.substring(0, 3).toUpperCase() : companyName.toUpperCase());

    return pw.Container(
      height: 140,
      child: pw.Stack(
        children: [
          // Clean blue accent bar at top right (no triangle tail)
          pw.Positioned(
            top: 0,
            right: 0,
            child: pw.Container(width: 240, height: 38, color: _primaryBlue),
          ),
          // Angled extension for a subtle geometric slash
          pw.Positioned(
            top: 0,
            right: 205,
            child: pw.Transform.rotate(
              angle: -0.45,
              child: pw.Container(width: 65, height: 38, color: _primaryBlue),
            ),
          ),
          // Thin secondary accent line below
          pw.Positioned(
            top: 44,
            right: 0,
            child: pw.Container(width: 180, height: 4, color: _primaryBlue),
          ),
          pw.Positioned(
            top: 44,
            right: 155,
            child: pw.Transform.rotate(
              angle: -0.45,
              child: pw.Container(width: 40, height: 4, color: _primaryBlue),
            ),
          ),
          // Content (rendered ON TOP of decorative shapes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 40, top: 24, right: 40),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Company logo + name — vertically stacked for tight alignment
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Circular logo
                    pw.Container(
                      width: 55,
                      height: 55,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: _primaryBlue, width: 2),
                        color: PdfColor.fromInt(0xFF222A35),
                      ),
                      child: pw.Center(
                        child: logoImage != null
                            ? pw.ClipOval(
                                child: pw.Image(logoImage,
                                    fit: pw.BoxFit.cover, width: 50, height: 50))
                            : pw.Text(
                                shortName,
                                style: pw.TextStyle(
                                  color: _primaryBlue,
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    // Company name left-aligned with logo edge
                    pw.Text(
                      companyName.toUpperCase(),
                      style: pw.TextStyle(
                        color: _white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                // Document title — right-aligned column (flex-end)
                // No badge container — plain white text avoids overlap with blue bar
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      documentType,
                      style: pw.TextStyle(
                        color: _white,
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '# $documentNumber',
                      style: pw.TextStyle(color: _white, fontSize: 10),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'DATE : ${Formatters.date(date)}',
                      style: pw.TextStyle(color: _white, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClientInfo(Customer? customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: _primaryBlue,
          child: pw.Text(
            'QUOTATION TO :',
            style: pw.TextStyle(color: _white, fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          customer?.name ?? 'Valued Customer',
          style: pw.TextStyle(color: _white, fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        if (customer?.address != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(customer!.address!, style: pw.TextStyle(color: _white, fontSize: 10)),
        ],
        if (customer?.phone != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(customer!.phone!, style: pw.TextStyle(color: _white, fontSize: 10)),
        ],
        if (customer?.email != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(customer!.email!, style: pw.TextStyle(color: _white, fontSize: 10)),
        ],
      ],
    );
  }

  static pw.Widget _buildQuotationTable(List<QuotationItemWithProduct> items) {
    // A4 content width with 40px margins = ~515pt
    // Column percentages: # 5%, CODE 20%, DESC auto, QTY 10%, PRICE 15%, DISC 10%, TOTAL 15%
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColor.fromInt(0xFFE0E0E0),
          width: 0.5,
        ),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(26),   // #      ~5%
        1: const pw.FixedColumnWidth(103),  // CODE   ~20% — fits P-2026-0001
        2: const pw.FlexColumnWidth(1),     // DESC   auto
        3: const pw.FixedColumnWidth(52),   // QTY    ~10%
        4: const pw.FixedColumnWidth(77),   // PRICE  ~15%
        5: const pw.FixedColumnWidth(52),   // DISC   ~10%
        6: const pw.FixedColumnWidth(77),   // TOTAL  ~15%
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _primaryBlue),
          children: [
            _darkTableHeader('#', align: pw.TextAlign.center),
            _darkTableHeader('CODE'),
            _darkTableHeader('DESCRIPTION'),
            _darkTableHeader('QTY', align: pw.TextAlign.center),
            _darkTableHeader('UNIT PRICE', align: pw.TextAlign.right),
            _darkTableHeader('DISC', align: pw.TextAlign.right),
            _darkTableHeader('TOTAL', align: pw.TextAlign.right),
          ],
        ),
        // Data rows with subtle striping
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          final lineTotal = (item.item.unitPrice * item.item.quantity) - item.item.discountAmount;
          final isEven = idx % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? _lightGrey : PdfColors.white,
            ),
            children: [
              _darkTableCell(idx.toString(), align: pw.TextAlign.center),
              // CODE — white-space: nowrap equivalent
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: pw.Text(
                  item.product.code,
                  maxLines: 1,
                  softWrap: false,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    color: PdfColors.black,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              _darkTableCell(item.product.name),
              _darkTableCell(item.item.quantity.toString(), align: pw.TextAlign.center),
              _darkTableCell('Rs. ${item.item.unitPrice.toStringAsFixed(2)}', align: pw.TextAlign.right),
              _darkTableCell(item.item.discountAmount > 0
                  ? 'Rs. ${item.item.discountAmount.toStringAsFixed(2)}'
                  : '-', align: pw.TextAlign.right),
              _darkTableCell('Rs. ${lineTotal.toStringAsFixed(2)}', align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _darkTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: pw.Text(
        text,
        textAlign: align,
        maxLines: 1,
        style: pw.TextStyle(
          color: _white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static pw.Widget _darkTableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(
          color: PdfColors.black,
          fontSize: 8,
        ),
      ),
    );
  }

  static pw.Widget _buildQuotationSummary(Quotation quotation) {
    // Right summary width = table's last 3 columns (PRICE 77 + DISC 52 + TOTAL 77) = 206pt
    const double summaryWidth = 206;

    return pw.Column(
      children: [
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Valid until badge
            pw.Expanded(
              child: quotation.validUntil != null
                  ? pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: _primaryBlue,
                      child: pw.Text(
                        'VALID UNTIL : ${Formatters.date(quotation.validUntil!)}',
                        style: pw.TextStyle(color: _white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    )
                  : pw.SizedBox(),
            ),
            pw.SizedBox(width: 16),
            // Right: Summary — fixed width aligned with table's right edge
            pw.SizedBox(
              width: summaryWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _quotationSumRow('Sub Total', quotation.subtotal),
                  if (quotation.discountAmount > 0) ...[
                    pw.SizedBox(height: 5),
                    _quotationSumRow('Discount', quotation.discountAmount),
                  ],
                  if (quotation.taxAmount > 0) ...[
                    pw.SizedBox(height: 5),
                    _quotationSumRow('Tax', quotation.taxAmount),
                  ],
                  pw.SizedBox(height: 14),
                  // TOTAL banner — full-width of summary block, right-aligned with table
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: _primaryBlue,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL',
                            style: pw.TextStyle(
                                color: _white,
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text('Rs. ${quotation.totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                color: _white,
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _quotationSumRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: PdfColor.fromInt(0xFFCED4DA), fontSize: 9)),
        pw.Text('Rs. ${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(color: _white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildQuotationFooter(String companyAddress, String companyPhone, DateTime? validUntil) {
    return pw.Column(
      children: [
        // Horizontal divider above footer
        pw.Container(height: 0.5, color: PdfColor.fromInt(0xFF3A4550)),
        pw.SizedBox(height: 16),
        // Two-column layout: Thank you / Terms left, Notes right
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left — Thank you + Terms
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Thank you for your interest!',
                    style: pw.TextStyle(
                      color: _white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Terms and Conditions',
                      style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFFCED4DA),
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Prices are subject to change without prior notice.\n'
                    'This quotation is valid for the period stated above.\n'
                    'Goods sold are not returnable or refundable.',
                    style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFFADB5BD),
                        fontSize: 7,
                        fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            // Right — Notes
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: _primaryBlue,
                    child: pw.Text('NOTES',
                        style: pw.TextStyle(
                            color: _white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Please confirm acceptance within the validity period.\n'
                    'Contact us for any queries regarding this quotation.',
                    style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFFADB5BD),
                        fontSize: 7.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        // Contact strip
        pw.Container(height: 0.5, color: PdfColor.fromInt(0xFF3A4550)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Text(companyAddress,
                style: pw.TextStyle(color: PdfColor.fromInt(0xFFCED4DA), fontSize: 7.5)),
            pw.SizedBox(width: 8),
            pw.Container(width: 1, height: 10, color: PdfColor.fromInt(0xFF3A4550)),
            pw.SizedBox(width: 8),
            pw.Text('Tel: $companyPhone',
                style: pw.TextStyle(color: PdfColor.fromInt(0xFFCED4DA), fontSize: 7.5)),
            pw.Spacer(),
            pw.Text(AppConstants.poweredBy,
                style: pw.TextStyle(color: PdfColor.fromInt(0xFFADB5BD), fontSize: 6)),
          ],
        ),
      ],
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

  /// Generates quotation PDF bytes (A4 format) with dark professional theme
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

    // Load logo image before building the page
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            color: _darkBackground,
            child: pw.Column(
              children: [
                // Header with blue accent and logo
                _buildDocumentHeader(companyName, quotation.quotationNumber, quotation.createdAt, 'QUOTATION', logoImage: logoImage),

                // Content
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Client info
                        _buildClientInfo(customer),
                        pw.SizedBox(height: 24),

                        // Items table
                        _buildQuotationTable(items),
                        pw.SizedBox(height: 6),

                        // Summary (includes its own top divider)
                        _buildQuotationSummary(quotation),

                        pw.Spacer(),

                        // Footer (includes its own top divider)
                        _buildQuotationFooter(companyAddress, companyPhone, quotation.validUntil),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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

// ==================== Professional Invoice Generator ====================

/// Data class for invoice items
class InvoiceItem {
  final String code;
  final String description;
  final int quantity;
  final double unitPrice;
  final double discount;
  final String? serialNumber;
  final String? warrantyInfo;

  const InvoiceItem({
    required this.code,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.serialNumber,
    this.warrantyInfo,
  });

  double get total => (unitPrice * quantity) - discount;
}

/// Data class for complete invoice data
class InvoiceData {
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final Uint8List? logoBytes;

  // Company info
  final String companyName;
  final String companyShortName;
  final String companyAddress;
  final String companyPhone;
  final String? companyEmail;
  final String? companyWebsite;
  final String? companyWhatsApp;

  // Customer info
  final String customerName;
  final String? customerAddress;
  final String? customerPhone;
  final String? customerEmail;

  // Items and totals
  final List<InvoiceItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;

  // Additional info
  final bool isCredit;
  final String? notes;
  final String? termsAndConditions;
  final String? paymentInfo;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;

  const InvoiceData({
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    this.logoBytes,
    required this.companyName,
    required this.companyShortName,
    required this.companyAddress,
    required this.companyPhone,
    this.companyEmail,
    this.companyWebsite,
    this.companyWhatsApp,
    required this.customerName,
    this.customerAddress,
    this.customerPhone,
    this.customerEmail,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0,
    this.taxAmount = 0,
    required this.totalAmount,
    this.paidAmount = 0,
    this.isCredit = false,
    this.notes,
    this.termsAndConditions,
    this.paymentInfo,
    this.bankName,
    this.accountNumber,
    this.accountName,
  });

  double get outstandingAmount => totalAmount - paidAmount;
}

/// Holds pre-loaded image assets for the invoice PDF
class _InvoiceImages {
  final pw.MemoryImage? logo;
  final pw.MemoryImage? phone;
  final pw.MemoryImage? whatsapp;
  final pw.MemoryImage? location;
  const _InvoiceImages({this.logo, this.phone, this.whatsapp, this.location});
}

/// Professional Invoice Generator — high-fidelity dark-theme reference design
class ProfessionalInvoiceGenerator {
  // ── Design Constants ──
  static const _accentBlue = PdfColor.fromInt(0xFF007BFF);
  static const _bg = PdfColor.fromInt(0xFF1A202C);
  static const _w = PdfColors.white;
  static const _rowAlt = PdfColor.fromInt(0xFFF7F8FA);
  static const _grey = PdfColor.fromInt(0xFFADB5BD);
  static const _greyLight = PdfColor.fromInt(0xFFCED4DA);

  // ── Asset Loading ──

  static Future<pw.MemoryImage?> _loadAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<_InvoiceImages> _loadImages() async {
    return _InvoiceImages(
      logo: await _loadAsset('assets/logo.png'),
      phone: await _loadAsset('assets/phone.png'),
      whatsapp: await _loadAsset('assets/whatsapp.png'),
      location: await _loadAsset('assets/location.png'),
    );
  }

  // ── Public API ──

  static Future<List<int>> generateInvoice(InvoiceData data) async {
    final pdf = pw.Document();
    final images = await _loadImages();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => _page(data, images),
    ));
    return pdf.save();
  }

  static Future<bool> printInvoice(InvoiceData data) async {
    final pdf = pw.Document();
    final images = await _loadImages();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => _page(data, images),
    ));
    return await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Invoice_${data.invoiceNumber}',
    );
  }

  static Future<String> saveInvoice(InvoiceData data) async {
    final bytes = await generateInvoice(data);
    final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/Invoices');
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = '${dir.path}/Invoice_${data.invoiceNumber}.pdf';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  static Future<InvoiceData> fromSale({
    required Sale sale,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    Uint8List? logoBytes,
    String? companyEmail,
    String? companyWebsite,
    String? companyWhatsApp,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? customerEmail,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    final words = companyName.split(' ');
    final shortName = words.length > 1
        ? words.map((w) => w.isNotEmpty ? w[0] : '').join()
        : (companyName.length > 3
            ? companyName.substring(0, 3).toUpperCase()
            : companyName.toUpperCase());
    return InvoiceData(
      invoiceNumber: sale.invoiceNumber,
      invoiceDate: sale.saleDate,
      logoBytes: logoBytes,
      companyName: companyName,
      companyShortName: shortName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyWebsite: companyWebsite,
      companyWhatsApp: companyWhatsApp,
      customerName: customerName ?? 'Walk-in Customer',
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      items: sale.items
          .map((i) => InvoiceItem(
                code: i.productCode ?? '-',
                description: i.productName ?? i.productId,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                discount: i.discountAmount,
                serialNumber:
                    i.serials.isNotEmpty ? i.serials.first.serialNumber : null,
              ))
          .toList(),
      subtotal: sale.subtotal,
      discountAmount: sale.discountAmount,
      taxAmount: sale.taxAmount,
      totalAmount: sale.totalAmount,
      paidAmount: sale.paidAmount,
      isCredit: sale.isCredit,
      notes: sale.notes,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PAGE SCAFFOLD
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _page(InvoiceData d, _InvoiceImages images) {
    return pw.Container(
      color: _bg,
      child: pw.Stack(
        children: [
          // ── Top-right decorative polygon (background layer) ──
          pw.Positioned(
            top: 0,
            right: 0,
            child: pw.Container(width: 220, height: 48, color: _accentBlue),
          ),
          pw.Positioned(
            top: 0,
            right: 185,
            child: pw.Transform.rotate(
              angle: -0.45,
              child: pw.Container(width: 70, height: 48, color: _accentBlue),
            ),
          ),
          pw.Positioned(
            top: 54,
            right: 0,
            child: pw.Container(width: 170, height: 5, color: _accentBlue),
          ),
          pw.Positioned(
            top: 54,
            right: 142,
            child: pw.Transform.rotate(
              angle: -0.45,
              child: pw.Container(width: 45, height: 5, color: _accentBlue),
            ),
          ),

          // ── Main content (rendered ON TOP of decorative shapes) ──
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _header(d, images),
                pw.SizedBox(height: 10),
                _slantedDivider(),
                pw.SizedBox(height: 10),
                _invoiceTo(d),
                pw.SizedBox(height: 16),
                _table(d),
                pw.SizedBox(height: 16),
                _totals(d),
                pw.Spacer(),
                _footer(d, images),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HEADER — circular logo + company name + INVOICE title
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _header(InvoiceData d, _InvoiceImages images) {
    // Determine which logo source to use: loaded asset > InvoiceData bytes > text fallback
    final pw.Widget logoContent;
    if (images.logo != null) {
      logoContent = pw.ClipOval(
          child: pw.Image(images.logo!,
              fit: pw.BoxFit.cover, width: 55, height: 55));
    } else if (d.logoBytes != null) {
      logoContent = pw.ClipOval(
          child: pw.Image(pw.MemoryImage(d.logoBytes!),
              fit: pw.BoxFit.cover, width: 55, height: 55));
    } else {
      logoContent = pw.Text(d.companyShortName,
          style: pw.TextStyle(
              color: _accentBlue,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold));
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Circular logo
        pw.Container(
          width: 60,
          height: 60,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: _accentBlue, width: 2.5),
            color: PdfColor.fromInt(0xFF222A35),
          ),
          child: pw.Center(child: logoContent),
        ),
        pw.SizedBox(width: 12),
        // Company name & address
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 8),
            pw.Text(d.companyName.toUpperCase(),
                style: pw.TextStyle(
                    color: _w,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5)),
            pw.SizedBox(height: 2),
            pw.Text(d.companyAddress,
                style: pw.TextStyle(color: _grey, fontSize: 8)),
          ],
        ),
        pw.Spacer(),
        // INVOICE title + meta — white text visible over blue geometric shapes
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('INVOICE',
                  style: pw.TextStyle(
                      color: _w,
                      fontSize: 36,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 3)),
              pw.SizedBox(height: 6),
              _metaRow('Invoice #', d.invoiceNumber),
              pw.SizedBox(height: 3),
              _metaRow('Date', Formatters.date(d.invoiceDate)),
              if (d.dueDate != null) ...[
                pw.SizedBox(height: 3),
                _metaRow('Due Date', Formatters.date(d.dueDate!)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label : ', style: pw.TextStyle(color: _grey, fontSize: 9)),
        pw.Text(value,
            style: pw.TextStyle(
                color: _w, fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SLANTED BLUE DIVIDER
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _slantedDivider() {
    // Full-width blue bar with a subtle skew effect using a stack
    return pw.SizedBox(
      height: 8,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Container(color: _accentBlue),
          ),
          // Angled notch on the left edge
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Transform.rotate(
              angle: 0.15,
              child: pw.Container(width: 60, height: 8, color: _accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INVOICE TO SECTION
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _invoiceTo(InvoiceData d) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: _accentBlue,
              child: pw.Text('INVOICE TO :',
                  style: pw.TextStyle(
                      color: _w,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9)),
            ),
            pw.SizedBox(height: 8),
            pw.Text(d.customerName,
                style: pw.TextStyle(
                    color: _w,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold)),
            if (d.customerAddress != null) ...[
              pw.SizedBox(height: 3),
              pw.Text(d.customerAddress!,
                  style: pw.TextStyle(color: _grey, fontSize: 9)),
            ],
            if (d.customerPhone != null) ...[
              pw.SizedBox(height: 3),
              pw.Text('Tel: ${d.customerPhone}',
                  style: pw.TextStyle(color: _grey, fontSize: 9)),
            ],
            if (d.customerEmail != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(d.customerEmail!,
                  style: pw.TextStyle(color: _grey, fontSize: 9)),
            ],
          ],
        ),
        pw.Spacer(),
        if (d.isCredit)
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: PdfColors.orange,
            child: pw.Text('CREDIT SALE',
                style: pw.TextStyle(
                    color: _w,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9)),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TABLE — 7 columns: #, CODE, DESCRIPTION, QTY,
  //          UNIT PRICE, DISC (Rs.), RATE, TOTAL
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _table(InvoiceData d) {
    const c0 = 22.0; // #
    const c1 = 50.0; // CODE
    const c3 = 28.0; // QTY
    const c4 = 64.0; // UNIT PRICE
    const c5 = 52.0; // DISC
    const c6 = 56.0; // RATE
    const c7 = 68.0; // TOTAL

    return pw.Column(children: [
      // ── Header ──
      pw.Container(
        color: _accentBlue,
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        child: pw.Row(children: [
          pw.SizedBox(
              width: c0,
              child: _th('#', align: pw.TextAlign.center)),
          pw.SizedBox(width: c1, child: _th('CODE')),
          pw.Expanded(child: _th('DESCRIPTION')),
          pw.SizedBox(
              width: c3,
              child: _th('QTY', align: pw.TextAlign.right)),
          pw.SizedBox(
              width: c4,
              child: _th('UNIT PRICE', align: pw.TextAlign.right)),
          pw.SizedBox(
              width: c5,
              child: _th('DISC (Rs.)', align: pw.TextAlign.right)),
          pw.SizedBox(
              width: c6,
              child: _th('RATE', align: pw.TextAlign.right)),
          pw.SizedBox(
              width: c7,
              child: _th('TOTAL', align: pw.TextAlign.right)),
        ]),
      ),
      // ── Data rows ──
      ...d.items.asMap().entries.map((e) {
        final idx = e.key;
        final item = e.value;
        final perUnitDisc =
            item.quantity > 0 ? item.discount / item.quantity : 0.0;
        final rate = item.unitPrice - perUnitDisc;

        return pw.Container(
          color: idx.isEven ? PdfColors.white : _rowAlt,
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Row(children: [
            pw.SizedBox(
                width: c0,
                child: _td('${idx + 1}', align: pw.TextAlign.center)),
            pw.SizedBox(width: c1, child: _td(item.code)),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.description,
                        style: const pw.TextStyle(
                            color: PdfColors.black, fontSize: 8)),
                    if (item.serialNumber != null)
                      pw.Text('S/N: ${item.serialNumber}',
                          style: const pw.TextStyle(
                              color: PdfColors.grey600, fontSize: 6)),
                    if (item.warrantyInfo != null)
                      pw.Text(item.warrantyInfo!,
                          style: pw.TextStyle(
                              color: _accentBlue, fontSize: 6)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(
                width: c3,
                child:
                    _td('${item.quantity}', align: pw.TextAlign.right)),
            pw.SizedBox(
                width: c4,
                child:
                    _td(_rs(item.unitPrice), align: pw.TextAlign.right)),
            pw.SizedBox(
                width: c5,
                child: _td(
                    item.discount > 0 ? _rs(item.discount) : '-',
                    align: pw.TextAlign.right)),
            pw.SizedBox(
                width: c6,
                child: _td(_rs(rate), align: pw.TextAlign.right)),
            pw.SizedBox(
                width: c7,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: pw.Text(_rs(item.total),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          color: PdfColors.black,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold)),
                )),
          ]),
        );
      }),
    ]);
  }

  // ══════════════════════════════════════════════════════════════
  //  TOTALS — Outstanding bar left, Summary right
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _totals(InvoiceData d) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Left: wide blue TOTAL OUTSTANDING bar ──
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            color: _accentBlue,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TOTAL OUTSTANDING',
                    style: pw.TextStyle(
                        color: _w,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text(_rs(d.outstandingAmount),
                    style: pw.TextStyle(
                        color: _w,
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        // ── Right: Sub Total, Discount, TOTAL banner ──
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _sumLine('Sub Total', d.subtotal),
              if (d.discountAmount > 0) ...[
                pw.SizedBox(height: 4),
                _sumLine('Discount', d.discountAmount),
              ],
              if (d.taxAmount > 0) ...[
                pw.SizedBox(height: 4),
                _sumLine('Tax', d.taxAmount),
              ],
              if (d.paidAmount > 0 && d.outstandingAmount > 0) ...[
                pw.SizedBox(height: 4),
                _sumLine('Paid', d.paidAmount),
              ],
              pw.SizedBox(height: 10),
              // Blue TOTAL banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                color: _accentBlue,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL',
                        style: pw.TextStyle(
                            color: _w,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(_rs(d.totalAmount),
                        style: pw.TextStyle(
                            color: _w,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sumLine(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(color: _greyLight, fontSize: 9)),
        pw.Text(_rs(amount),
            style: pw.TextStyle(
                color: _w, fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FOOTER — Thank you + Terms (left), Payment Info (right),
  //           Contact strip, Developer credit
  // ══════════════════════════════════════════════════════════════

  static pw.Widget _footer(InvoiceData d, _InvoiceImages images) {
    return pw.Column(
      children: [
        // ── Two-column: Terms left, Payment right ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left column
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Thank you for your business!',
                      style: pw.TextStyle(
                          color: _w,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('Terms and Conditions',
                      style: pw.TextStyle(
                          color: _greyLight,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    d.termsAndConditions ??
                        'Goods sold are not returnable or refundable.\n'
                            'Warranty is void if the product is physically damaged.\n'
                            'This invoice serves as your warranty card.',
                    style: pw.TextStyle(
                        color: _grey,
                        fontSize: 7,
                        fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            // Right column
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    color: _accentBlue,
                    child: pw.Text('PAYMENT INFO',
                        style: pw.TextStyle(
                            color: _w,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8)),
                  ),
                  pw.SizedBox(height: 6),
                  if (d.bankName != null)
                    pw.Text('Bank: ${d.bankName}',
                        style: pw.TextStyle(color: _grey, fontSize: 7.5)),
                  if (d.accountName != null)
                    pw.Text('A/C Name: ${d.accountName}',
                        style: pw.TextStyle(color: _grey, fontSize: 7.5)),
                  if (d.accountNumber != null)
                    pw.Text('A/C No: ${d.accountNumber}',
                        style: pw.TextStyle(color: _grey, fontSize: 7.5)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    d.paidAmount >= d.totalAmount ? 'Paid' : 'Not Paid',
                    style: pw.TextStyle(
                      color: d.paidAmount >= d.totalAmount
                          ? PdfColors.green300
                          : PdfColors.red300,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        // ── Bottom contact strip — single clean horizontal row ──
        pw.Container(height: 0.5, color: _grey),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            // [Location icon] Address
            _contactIcon(images.location, 'A', _accentBlue),
            pw.SizedBox(width: 4),
            pw.Text(d.companyAddress,
                style: pw.TextStyle(color: _greyLight, fontSize: 7.5)),
            pw.SizedBox(width: 8),
            pw.Container(width: 1, height: 12, color: _grey),
            pw.SizedBox(width: 8),
            // [Phone icon] Phone Number
            _contactIcon(images.phone, 'T', _accentBlue),
            pw.SizedBox(width: 4),
            pw.Text(d.companyPhone,
                style: pw.TextStyle(color: _greyLight, fontSize: 7.5)),
            if (d.companyWhatsApp != null) ...[
              pw.SizedBox(width: 8),
              pw.Container(width: 1, height: 12, color: _grey),
              pw.SizedBox(width: 8),
              // [WhatsApp icon] WhatsApp Number
              _contactIcon(images.whatsapp, 'W', PdfColor.fromInt(0xFF25D366)),
              pw.SizedBox(width: 4),
              pw.Text(d.companyWhatsApp!,
                  style: pw.TextStyle(color: _greyLight, fontSize: 7.5)),
            ],
            pw.Spacer(),
            if (d.companyEmail != null)
              pw.Text(d.companyEmail!,
                  style: pw.TextStyle(color: _grey, fontSize: 7)),
            if (d.companyWebsite != null) ...[
              pw.SizedBox(width: 10),
              pw.Text(d.companyWebsite!,
                  style: pw.TextStyle(color: _grey, fontSize: 7)),
            ],
          ],
        ),
        pw.SizedBox(height: 10),
        // ── Developer credit ──
        pw.Center(
          child: pw.Text(AppConstants.poweredBy,
              style: pw.TextStyle(color: _grey, fontSize: 6)),
        ),
      ],
    );
  }

  /// Renders a contact icon: real image if loaded, colored square with letter fallback
  static pw.Widget _contactIcon(
      pw.MemoryImage? icon, String fallbackLetter, PdfColor bgColor) {
    if (icon != null) {
      return pw.Container(
        width: 14,
        height: 14,
        child: pw.Image(icon, fit: pw.BoxFit.contain),
      );
    }
    return pw.Container(
      width: 14,
      height: 14,
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Center(
        child: pw.Text(fallbackLetter,
            style: pw.TextStyle(
                color: _w, fontSize: 7, fontWeight: pw.FontWeight.bold)),
      ),
    );
  }

  // ── Styled Helpers ──

  static String _rs(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  static pw.Widget _th(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              color: _w, fontWeight: pw.FontWeight.bold, fontSize: 8)),
    );
  }

  static pw.Widget _td(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
      child: pw.Text(text,
          textAlign: align,
          style: const pw.TextStyle(color: PdfColors.black, fontSize: 8)),
    );
  }
}
