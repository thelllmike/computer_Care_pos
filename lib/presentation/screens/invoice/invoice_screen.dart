import 'package:flutter/material.dart';

// ============================================================
//  STANDALONE INVOICE SCREEN
//  Run with: flutter run -t lib/presentation/screens/invoice/invoice_screen.dart
// ============================================================

void main() {
  // Sample data — replace with your real data source
  final sampleData = InvoiceScreenData(
    companyName: 'M TRONIC',
    companyAddress: '274/A, Galle Road, Henegama, Akuressa',
    companyPhone: '076 674 1200',
    companyShortName: 'MT',
    invoiceNumber: 'INV-2026-0042',
    invoiceDate: '2026-01-28',
    customerName: 'sachin',
    customerPhone: '0783100177',
    isCredit: true,
    items: [
      InvoiceLineItem(
        code: 'P-2026-0003',
        description: 'power',
        qty: 1,
        unitPrice: 10000,
        disc: 0,
        rate: 10000,
        total: 10000,
      ),
      InvoiceLineItem(
        code: 'P-2026-0001',
        description: 'Ram',
        qty: 1,
        unitPrice: 3000,
        disc: 0,
        rate: 3000,
        total: 3000,
      ),
      InvoiceLineItem(
        code: 'P-2026-0002',
        description: 'Hard disk',
        qty: 1,
        unitPrice: 10000,
        disc: 0,
        rate: 10000,
        total: 10000,
      ),
    ],
    subTotal: 23000,
    paidAmount: 18000,
    totalAmount: 23000,
    totalOutstanding: 5000,
    bankName: 'Bank of Ceylon',
    accountName: 'M Tronic',
    accountNumber: '12345678',
    isPaid: false,
  );

  runApp(InvoiceApp(data: sampleData));
}

// ── Design Colors ──
const Color _accentRed = Color(0xFFFF0F10);
const Color _bgDark = Color(0xFF1B1E2F);
const Color _white = Colors.white;
const Color _grey = Color(0xFFADB5BD);
const Color _greyLight = Color(0xFFCED4DA);
const Color _creditOrange = Color(0xFFE8A838);
const Color _rowEven = Color(0xFFF7F8FA);
const Color _rowOdd = Colors.white;

// ════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════

class InvoiceLineItem {
  final String code;
  final String description;
  final int qty;
  final double unitPrice;
  final double disc;
  final double rate;
  final double total;

  const InvoiceLineItem({
    required this.code,
    required this.description,
    required this.qty,
    required this.unitPrice,
    required this.disc,
    required this.rate,
    required this.total,
  });
}

class InvoiceScreenData {
  // Company
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String companyShortName;

  // Invoice meta
  final String invoiceNumber;
  final String invoiceDate;

  // Customer
  final String customerName;
  final String? customerPhone;
  final bool isCredit;

  // Line items
  final List<InvoiceLineItem> items;

  // Totals
  final double subTotal;
  final double paidAmount;
  final double totalAmount;
  final double totalOutstanding;

  // Payment info
  final String? bankName;
  final String? accountName;
  final String? accountNumber;
  final bool isPaid;

  const InvoiceScreenData({
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyShortName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerName,
    this.customerPhone,
    this.isCredit = false,
    required this.items,
    required this.subTotal,
    required this.paidAmount,
    required this.totalAmount,
    required this.totalOutstanding,
    this.bankName,
    this.accountName,
    this.accountNumber,
    this.isPaid = false,
  });
}

// ════════════════════════════════════════════════════════════════
//  APP WRAPPER (for standalone run)
// ════════════════════════════════════════════════════════════════

class InvoiceApp extends StatelessWidget {
  final InvoiceScreenData data;
  const InvoiceApp({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Invoice',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bgDark,
      ),
      home: InvoiceScreen(data: data),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  INVOICE SCREEN
// ════════════════════════════════════════════════════════════════

class InvoiceScreen extends StatelessWidget {
  final InvoiceScreenData data;
  const InvoiceScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    Container(height: 3, color: _accentRed),
                    const SizedBox(height: 20),
                    _buildCustomerSection(),
                    const SizedBox(height: 24),
                    _buildDataTable(),
                    const SizedBox(height: 28),
                    _buildTotals(),
                    const SizedBox(height: 32),
                    // Authorized Signature — right-aligned
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(width: 180, height: 0.5, color: _grey),
                          const SizedBox(height: 4),
                          const Text(
                            'Authorized Signature',
                            style: TextStyle(
                              color: _greyLight,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Logo + Company Info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accentRed, width: 2.5),
                color: const Color(0xFF232738),
              ),
              child: Center(
                child: Text(
                  data.companyShortName,
                  style: const TextStyle(
                    color: _accentRed,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  data.companyName,
                  style: const TextStyle(
                    color: _white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.companyAddress,
                  style: const TextStyle(color: _greyLight, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  data.companyPhone,
                  style: const TextStyle(color: _white, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        // Right: INVOICE text — clean, no decorative shapes
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'INVOICE',
              style: TextStyle(
                color: _white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            _MetaRow(label: 'Invoice #', value: data.invoiceNumber),
            const SizedBox(height: 3),
            _MetaRow(label: 'Date', value: data.invoiceDate),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  CUSTOMER SECTION
  // ════════════════════════════════════════════════════════════

  Widget _buildCustomerSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              color: _accentRed,
              child: const Text(
                'INVOICE TO :',
                style: TextStyle(
                  color: _white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  data.customerName.toUpperCase(),
                  style: const TextStyle(
                    color: _white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (data.customerPhone != null) ...[
                  const SizedBox(width: 16),
                  const Text('|', style: TextStyle(color: _grey, fontSize: 16)),
                  const SizedBox(width: 16),
                  Text(
                    'Tel: ${data.customerPhone}',
                    style: const TextStyle(color: _greyLight, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
        const Spacer(),
        if (data.isCredit)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _creditOrange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'CREDIT SALE',
              style: TextStyle(
                color: _white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DATA TABLE
  // ════════════════════════════════════════════════════════════

  Widget _buildDataTable() {
    return Column(
      children: [
        Container(
          color: _accentRed,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: const Row(
            children: [
              _HeaderCell('#', width: 30, align: TextAlign.center),
              _HeaderCell('CODE', width: 110),
              Expanded(child: _HeaderCellExpanded('DESCRIPTION')),
              _HeaderCell('QTY', width: 45, align: TextAlign.center),
              _HeaderCell('UNIT PRICE', width: 90, align: TextAlign.right),
              _HeaderCell('DISC', width: 60, align: TextAlign.right),
              _HeaderCell('RATE', width: 80, align: TextAlign.right),
              _HeaderCell('TOTAL', width: 90, align: TextAlign.right),
            ],
          ),
        ),
        ...data.items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          final isEven = idx % 2 == 0;
          return Container(
            color: isEven ? _rowEven : _rowOdd,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                _DataCell('$idx', width: 30, align: TextAlign.center),
                _DataCell(item.code, width: 110, bold: true),
                Expanded(child: _DataCellExpanded(item.description)),
                _DataCell('${item.qty}', width: 45, align: TextAlign.center),
                _DataCell(_formatNum(item.unitPrice),
                    width: 90, align: TextAlign.right),
                _DataCell(
                    item.disc > 0 ? _formatNum(item.disc) : '-',
                    width: 60,
                    align: TextAlign.right),
                _DataCell(_formatNum(item.rate),
                    width: 80, align: TextAlign.right),
                _DataCell(_formatNum(item.total),
                    width: 90, align: TextAlign.right, bold: true),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TOTALS
  // ════════════════════════════════════════════════════════════

  Widget _buildTotals() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: TOTAL OUTSTANDING
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            color: _accentRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL OUTSTANDING',
                  style: TextStyle(
                    color: _white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. ${data.totalOutstanding.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Right: Sub Total, Paid, TOTAL strip
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSumRow(
                  'Sub Total', 'Rs. ${_formatNum(data.subTotal)}'),
              const SizedBox(height: 8),
              _buildSumRow(
                  'Paid', 'Rs. ${_formatNum(data.paidAmount)}'),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                color: _accentRed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: _white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${data.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _greyLight, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: _white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FOOTER
  // ════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Thank you + Terms
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thank you for your business!',
                    style: TextStyle(
                      color: _white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Terms and Conditions',
                    style: TextStyle(
                      color: _greyLight,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Goods sold are not returnable or refundable.\n'
                    'Warranty is void if the product is physically damaged.\n'
                    'This invoice serves as your warranty card.',
                    style: TextStyle(
                      color: _grey,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right: Payment Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    color: _accentRed,
                    child: const Text(
                      'PAYMENT INFO',
                      style: TextStyle(
                        color: _white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (data.bankName != null)
                    Text('Bank: ${data.bankName}',
                        style: const TextStyle(color: _grey, fontSize: 10)),
                  if (data.accountName != null) ...[
                    const SizedBox(height: 2),
                    Text('A/C Name: ${data.accountName}',
                        style: const TextStyle(color: _grey, fontSize: 10)),
                  ],
                  if (data.accountNumber != null) ...[
                    const SizedBox(height: 2),
                    Text('A/C No: ${data.accountNumber}',
                        style: const TextStyle(color: _grey, fontSize: 10)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    data.isPaid ? 'Paid' : 'Not Paid',
                    style: TextStyle(
                      color: data.isPaid ? Colors.green : _accentRed,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Bottom contact strip
        Container(height: 0.5, color: _grey),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _accentRed,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Icon(Icons.location_on, color: _white, size: 13),
            ),
            const SizedBox(width: 6),
            Text(data.companyAddress,
                style: const TextStyle(color: _greyLight, fontSize: 10)),
            const SizedBox(width: 12),
            Container(width: 1, height: 16, color: _grey),
            const SizedBox(width: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _accentRed,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Icon(Icons.phone, color: _white, size: 13),
            ),
            const SizedBox(width: 6),
            Text(data.companyPhone,
                style: const TextStyle(color: _greyLight, fontSize: 10)),
            const Spacer(),
            const Text('Powered by cleverproject.lk',
                style: TextStyle(color: _grey, fontSize: 8)),
          ],
        ),
      ],
    );
  }

  static String _formatNum(double value) {
    if (value == value.truncateToDouble()) {
      final intVal = value.toInt();
      final str = intVal.toString();
      final buffer = StringBuffer();
      int count = 0;
      for (int i = str.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) buffer.write(',');
        buffer.write(str[i]);
        count++;
      }
      return buffer.toString().split('').reversed.join();
    }
    return value.toStringAsFixed(2);
  }
}

// ════════════════════════════════════════════════════════════════
//  REUSABLE TABLE CELL WIDGETS
// ════════════════════════════════════════════════════════════════

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label : ',
            style: const TextStyle(color: _grey, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: _white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;
  const _HeaderCell(this.text,
      {required this.width, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: align,
          style: const TextStyle(
              color: _white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.3)),
    );
  }
}

class _HeaderCellExpanded extends StatelessWidget {
  final String text;
  const _HeaderCellExpanded(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: _white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.3));
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;
  final bool bold;
  const _DataCell(this.text,
      {required this.width, this.align = TextAlign.left, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}

class _DataCellExpanded extends StatelessWidget {
  final String text;
  const _DataCellExpanded(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: Colors.black87, fontSize: 11));
  }
}
