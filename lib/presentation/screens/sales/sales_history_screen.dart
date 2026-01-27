import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/sales_dao.dart';
import '../../providers/core/database_provider.dart';
import '../../providers/inventory/customer_provider.dart';
import '../../providers/sales/sales_provider.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(salesHistoryFilterProvider);
    final salesAsync = ref.watch(salesHistoryProvider);
    final summaryAsync = ref.watch(salesHistorySummaryProvider);
    final customersAsync = ref.watch(customersProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Sales History'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(salesHistoryProvider);
                ref.invalidate(salesHistorySummaryProvider);
              },
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              summaryAsync.when(
                data: (summary) => Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Sales',
                        value: summary.totalSales.toString(),
                        icon: FluentIcons.shopping_cart,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Amount',
                        value: Formatters.currency(summary.totalAmount),
                        icon: FluentIcons.money,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Paid',
                        value:
                            '${summary.paidCount} (${Formatters.currency(summary.totalPaid)})',
                        icon: FluentIcons.completed,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Outstanding',
                        value: Formatters.currency(summary.totalOutstanding),
                        icon: FluentIcons.warning,
                        color: summary.totalOutstanding > 0
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                loading: () => const Row(
                  children: [
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                  ],
                ),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Filters
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(FluentIcons.filter),
                          const SizedBox(width: 16),
                          // Date filters
                          const Text('From: '),
                          DatePicker(
                            selected: filter.startDate ?? DateTime.now(),
                            onChanged: (date) {
                              ref
                                  .read(salesHistoryFilterProvider.notifier)
                                  .state = filter.copyWith(startDate: date);
                            },
                          ),
                          const SizedBox(width: 16),
                          const Text('To: '),
                          DatePicker(
                            selected: filter.endDate ?? DateTime.now(),
                            onChanged: (date) {
                              ref
                                  .read(salesHistoryFilterProvider.notifier)
                                  .state = filter.copyWith(endDate: date);
                            },
                          ),
                          const SizedBox(width: 16),
                          // Customer filter
                          customersAsync.when(
                            data: (customers) => ComboBox<String?>(
                              placeholder: const Text('All Customers'),
                              value: filter.customerId,
                              items: [
                                const ComboBoxItem(
                                    value: null, child: Text('All Customers')),
                                ...customers.map((c) => ComboBoxItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    )),
                              ],
                              onChanged: (value) {
                                ref
                                    .read(salesHistoryFilterProvider.notifier)
                                    .state = filter.copyWith(
                                  customerId: value,
                                  clearCustomer: value == null,
                                );
                              },
                            ),
                            loading: () =>
                                const SizedBox(width: 150, child: ProgressRing()),
                            error: (_, __) => const SizedBox(width: 150),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(FluentIcons.search),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextBox(
                              controller: _searchController,
                              placeholder: 'Search by invoice number...',
                              onSubmitted: (value) {
                                ref
                                    .read(salesHistoryFilterProvider.notifier)
                                    .state = filter.copyWith(
                                  searchQuery: value.isEmpty ? null : value,
                                  clearSearch: value.isEmpty,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Button(
                            child: const Text('Search'),
                            onPressed: () {
                              ref
                                  .read(salesHistoryFilterProvider.notifier)
                                  .state = filter.copyWith(
                                searchQuery: _searchController.text.isEmpty
                                    ? null
                                    : _searchController.text,
                                clearSearch: _searchController.text.isEmpty,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Button(
                            child: const Text('Clear'),
                            onPressed: () {
                              _searchController.clear();
                              final now = DateTime.now();
                              ref
                                  .read(salesHistoryFilterProvider.notifier)
                                  .state = SalesHistoryFilterState(
                                startDate: DateTime(now.year, now.month, 1),
                                endDate: now,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sales list
              Text('Sales', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 12),
              salesAsync.when(
                data: (sales) {
                  if (sales.isEmpty) {
                    return Card(
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.shopping_cart,
                                  size: 48, color: Colors.grey[100]),
                              const SizedBox(height: 16),
                              Text('No sales found',
                                  style: TextStyle(color: Colors.grey[100])),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: Column(
                      children: sales
                          .map((sale) => _SaleTile(
                                sale: sale,
                                onTap: () =>
                                    _showSaleDetailDialog(context, ref, sale),
                              ))
                          .toList(),
                    ),
                  );
                },
                loading: () => const Card(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: ProgressRing()),
                  ),
                ),
                error: (e, _) => Card(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: Text('Error: $e')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSaleDetailDialog(
      BuildContext context, WidgetRef ref, SaleWithDetails sale) {
    showDialog(
      context: context,
      builder: (context) => _SaleDetailDialog(sale: sale),
    );
  }
}

// Summary Card Widget
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(color: Colors.grey[100])),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: FluentTheme.of(context).typography.subtitle?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardLoading extends StatelessWidget {
  const _SummaryCardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: ProgressRing()),
      ),
    );
  }
}

// Sale Tile Widget
class _SaleTile extends StatelessWidget {
  final SaleWithDetails sale;
  final VoidCallback onTap;

  const _SaleTile({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          sale.isFullyPaid ? FluentIcons.completed : FluentIcons.clock,
          color: _getStatusColor(),
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (sale.customerName != null)
                  Text(
                    sale.customerName!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                  ),
              ],
            ),
          ),
          Text(
            Formatters.currency(sale.totalAmount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            Formatters.date(sale.saleDate),
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
          const SizedBox(width: 16),
          _PaymentStatusBadge(status: sale.paymentStatus),
          if (!sale.isFullyPaid) ...[
            const Spacer(),
            Text(
              'Due: ${Formatters.currency(sale.balanceDue)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      onPressed: onTap,
    );
  }

  Color _getStatusColor() {
    if (sale.isFullyPaid) return Colors.green;
    if (sale.paidAmount > 0) return Colors.orange;
    return Colors.red;
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final String status;

  const _PaymentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Paid':
        color = Colors.green;
        break;
      case 'Partial':
        color = Colors.orange;
        break;
      default:
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Sale Detail Dialog
class _SaleDetailDialog extends ConsumerWidget {
  final SaleWithDetails sale;

  const _SaleDetailDialog({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleDetailAsync = ref.watch(saleDetailProvider(sale.sale.id));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800),
      title: Row(
        children: [
          Expanded(child: Text('Invoice ${sale.invoiceNumber}')),
          _PaymentStatusBadge(status: sale.paymentStatus),
        ],
      ),
      content: SingleChildScrollView(
        child: saleDetailAsync.when(
          data: (detail) {
            if (detail == null) {
              return const Text('Sale not found');
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sale Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _InfoRow(
                                label: 'Date',
                                value: Formatters.dateTime(detail.sale.saleDate),
                              ),
                            ),
                            Expanded(
                              child: _InfoRow(
                                label: 'Customer',
                                value: detail.customerName ?? 'Walk-in',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoRow(
                                label: 'Subtotal',
                                value: Formatters.currency(detail.subtotal),
                              ),
                            ),
                            Expanded(
                              child: _InfoRow(
                                label: 'Discount',
                                value: Formatters.currency(detail.discountAmount),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoRow(
                                label: 'Tax',
                                value: Formatters.currency(detail.taxAmount),
                              ),
                            ),
                            Expanded(
                              child: _InfoRow(
                                label: 'Total',
                                value: Formatters.currency(detail.totalAmount),
                                valueStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoRow(
                                label: 'Paid',
                                value: Formatters.currency(detail.paidAmount),
                                valueStyle: TextStyle(color: Colors.green),
                              ),
                            ),
                            Expanded(
                              child: _InfoRow(
                                label: 'Balance Due',
                                value: Formatters.currency(detail.balanceDue),
                                valueStyle: TextStyle(
                                  color: detail.balanceDue > 0
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Items
                Text('Items',
                    style: FluentTheme.of(context).typography.subtitle),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('Product')),
                            Expanded(child: Text('Qty', textAlign: TextAlign.center)),
                            Expanded(child: Text('Price', textAlign: TextAlign.right)),
                            Expanded(child: Text('Total', textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      // Items
                      ...detail.items.map((item) => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.productName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                            item.productCode,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[100]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item.quantity.toString(),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        Formatters.currency(item.unitPrice),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        Formatters.currency(item.totalPrice),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.isSerialized) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: item.serialNumberList
                                        .map((sn) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                sn,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payments
                Text('Payments',
                    style: FluentTheme.of(context).typography.subtitle),
                const SizedBox(height: 8),
                Card(
                  child: detail.payments.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No payments recorded'),
                        )
                      : Column(
                          children: detail.payments
                              .map((payment) => ListTile(
                                    leading: Icon(
                                      _getPaymentIcon(payment.paymentMethod),
                                      color: Colors.green,
                                    ),
                                    title: Text(payment.paymentMethod),
                                    subtitle: Text(
                                        Formatters.dateTime(payment.paymentDate)),
                                    trailing: Text(
                                      Formatters.currency(payment.amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: ProgressRing()),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return FluentIcons.money;
      case 'CARD':
        return FluentIcons.payment_card;
      case 'BANK':
        return FluentIcons.bank;
      case 'CHEQUE':
        return FluentIcons.document;
      default:
        return FluentIcons.money;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[100]),
          ),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
