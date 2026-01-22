import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/payment_method.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/credit_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../../services/printing/receipt_printer.dart';
import '../../providers/credits/credit_provider.dart';
import '../../providers/core/database_provider.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(creditSummaryProvider);
    final searchQuery = ref.watch(creditSearchQueryProvider);
    final filterType = ref.watch(creditFilterProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Credit Management'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.money),
              label: const Text('Receive Payment'),
              onPressed: () => _showPaymentDialog(context, ref),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.chart),
              label: const Text('Aging Report'),
              onPressed: () => _showAgingReportDialog(context, ref),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(creditSummaryProvider);
                ref.invalidate(outstandingCustomersProvider);
                ref.invalidate(agingSummaryProvider);
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
                        title: 'Total Outstanding',
                        value: Formatters.currency(summary.totalOutstanding),
                        subtitle: '${summary.creditCustomersCount} customers',
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Overdue (30+ days)',
                        value: Formatters.currency(summary.overdueAmount),
                        subtitle: 'Requires attention',
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Collected This Month',
                        value: Formatters.currency(summary.collectedThisMonth),
                        subtitle: 'Payments received',
                        color: AppTheme.successColor,
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
                  ],
                ),
                error: (e, _) => InfoBar(
                  title: const Text('Error loading summary'),
                  content: Text(e.toString()),
                  severity: InfoBarSeverity.error,
                ),
              ),
              const SizedBox(height: 24),

              // Search and filter
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      placeholder: 'Search by customer name or phone...',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(FluentIcons.search, size: 16),
                      ),
                      onChanged: (value) =>
                          ref.read(creditSearchQueryProvider.notifier).state = value,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ComboBox<CreditFilterType>(
                    value: filterType,
                    items: CreditFilterType.values
                        .map((f) => ComboBoxItem(
                              value: f,
                              child: Text(_getFilterLabel(f)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(creditFilterProvider.notifier).state = value;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Outstanding Receivables list
              Text('Outstanding Receivables',
                  style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              _OutstandingList(searchQuery: searchQuery, filterType: filterType),
            ],
          ),
        ),
      ],
    );
  }

  String _getFilterLabel(CreditFilterType type) {
    switch (type) {
      case CreditFilterType.all:
        return 'All';
      case CreditFilterType.current:
        return 'Current (0-30 days)';
      case CreditFilterType.overdue30:
        return 'Overdue 31-60 days';
      case CreditFilterType.overdue60:
        return 'Overdue 61-90 days';
      case CreditFilterType.overdue90:
        return 'Overdue 90+ days';
    }
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _ReceivePaymentDialog(),
    );
  }

  void _showAgingReportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AgingReportDialog(),
    );
  }
}

// ==================== Summary Card ====================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: FluentTheme.of(context)
                    .typography
                    .body
                    ?.copyWith(color: Colors.grey[100])),
            const SizedBox(height: 8),
            Text(
              value,
              style: FluentTheme.of(context).typography.subtitle?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: FluentTheme.of(context)
                    .typography
                    .caption
                    ?.copyWith(color: Colors.grey[100])),
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

// ==================== Outstanding List ====================

class _OutstandingList extends ConsumerWidget {
  final String searchQuery;
  final CreditFilterType filterType;

  const _OutstandingList({
    required this.searchQuery,
    required this.filterType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agingAsync = ref.watch(agingByCustomerProvider);

    return agingAsync.when(
      data: (customers) {
        var filtered = customers;

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          filtered = filtered
              .where((c) =>
                  c.customerName.toLowerCase().contains(query) ||
                  (c.customerPhone?.toLowerCase().contains(query) ?? false))
              .toList();
        }

        // Apply type filter
        filtered = _applyFilter(filtered, filterType);

        if (filtered.isEmpty) {
          return Card(
            child: SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.completed_solid,
                        size: 48, color: AppTheme.successColor),
                    const SizedBox(height: 16),
                    Text('No outstanding credits',
                        style: TextStyle(color: Colors.grey[100])),
                    const SizedBox(height: 8),
                    Text('All accounts are settled!',
                        style: TextStyle(fontSize: 12, color: Colors.grey[100])),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: filtered
                .map((customer) => _CustomerCreditTile(
                      customerAging: customer,
                      onTap: () =>
                          _showCustomerDetailDialog(context, ref, customer),
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
    );
  }

  List<CustomerAging> _applyFilter(
      List<CustomerAging> customers, CreditFilterType filter) {
    switch (filter) {
      case CreditFilterType.all:
        return customers;
      case CreditFilterType.current:
        return customers.where((c) => c.oldestInvoiceDays <= 30).toList();
      case CreditFilterType.overdue30:
        return customers
            .where((c) => c.oldestInvoiceDays > 30 && c.oldestInvoiceDays <= 60)
            .toList();
      case CreditFilterType.overdue60:
        return customers
            .where((c) => c.oldestInvoiceDays > 60 && c.oldestInvoiceDays <= 90)
            .toList();
      case CreditFilterType.overdue90:
        return customers.where((c) => c.oldestInvoiceDays > 90).toList();
    }
  }

  void _showCustomerDetailDialog(
      BuildContext context, WidgetRef ref, CustomerAging customer) {
    showDialog(
      context: context,
      builder: (context) =>
          _CustomerCreditDetailDialog(customerId: customer.customer.id),
    );
  }
}

// ==================== Customer Credit Tile ====================

class _CustomerCreditTile extends StatelessWidget {
  final CustomerAging customerAging;
  final VoidCallback onTap;

  const _CustomerCreditTile({
    required this.customerAging,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = customerAging.oldestInvoiceDays > 30;

    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isOverdue
              ? AppTheme.errorColor.withValues(alpha: 0.1)
              : AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          FluentIcons.contact,
          color: isOverdue ? AppTheme.errorColor : AppTheme.primaryColor,
        ),
      ),
      title: Row(
        children: [
          Text(customerAging.customerName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (isOverdue) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${customerAging.oldestInvoiceDays} days',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(customerAging.customerPhone ?? 'No phone'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Formatters.currency(customerAging.total),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isOverdue ? AppTheme.errorColor : null,
            ),
          ),
          if (customerAging.over90 > 0)
            Text(
              '90+ days: ${Formatters.currency(customerAging.over90)}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.errorColor,
              ),
            ),
        ],
      ),
      onPressed: onTap,
    );
  }
}

// ==================== Customer Credit Detail Dialog ====================

class _CustomerCreditDetailDialog extends ConsumerStatefulWidget {
  final String customerId;

  const _CustomerCreditDetailDialog({required this.customerId});

  @override
  ConsumerState<_CustomerCreditDetailDialog> createState() =>
      _CustomerCreditDetailDialogState();
}

class _CustomerCreditDetailDialogState
    extends ConsumerState<_CustomerCreditDetailDialog> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final outstandingAsync =
        ref.watch(customerOutstandingSalesProvider(widget.customerId));
    final statementAsync = ref.watch(customerStatementProvider(
      CustomerStatementParams(customerId: widget.customerId),
    ));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      title: const Text('Customer Credit Details'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ToggleButton(
                checked: _selectedTab == 0,
                onChanged: (_) => setState(() => _selectedTab = 0),
                child: const Text('Outstanding Invoices'),
              ),
              const SizedBox(width: 8),
              ToggleButton(
                checked: _selectedTab == 1,
                onChanged: (_) => setState(() => _selectedTab = 1),
                child: const Text('Statement'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedTab == 0
                ? _buildOutstandingTab(outstandingAsync)
                : _buildStatementTab(statementAsync),
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          child: const Text('Receive Payment'),
          onPressed: () {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              builder: (context) =>
                  _ReceivePaymentDialog(preselectedCustomerId: widget.customerId),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOutstandingTab(AsyncValue<List<OutstandingSale>> asyncValue) {
    return asyncValue.when(
      data: (sales) {
        if (sales.isEmpty) {
          return const Center(child: Text('No outstanding invoices'));
        }
        return ListView.builder(
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getAgingColor(sale.daysSinceSale).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${sale.daysSinceSale}d',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getAgingColor(sale.daysSinceSale),
                    ),
                  ),
                ),
              ),
              title: Text(sale.invoiceNumber),
              subtitle: Text(Formatters.date(sale.saleDate)),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Formatters.currency(sale.outstandingAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'of ${Formatters.currency(sale.totalAmount)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildStatementTab(
      AsyncValue<List<CreditTransactionWithDetails>> asyncValue) {
    return asyncValue.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Center(child: Text('No transactions found'));
        }
        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index];
            final isDebit = txn.isDebit;
            return ListTile(
              leading: Icon(
                isDebit ? FluentIcons.remove : FluentIcons.add,
                color: isDebit ? AppTheme.errorColor : AppTheme.successColor,
              ),
              title: Text(txn.type.displayName),
              subtitle: Text(Formatters.dateTime(txn.transaction.transactionDate)),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${isDebit ? '+' : '-'} ${Formatters.currency(txn.transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDebit ? AppTheme.errorColor : AppTheme.successColor,
                    ),
                  ),
                  Text(
                    'Balance: ${Formatters.currency(txn.transaction.balanceAfter)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Color _getAgingColor(int days) {
    if (days <= 30) return AppTheme.successColor;
    if (days <= 60) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}

// ==================== Receive Payment Dialog ====================

class _ReceivePaymentDialog extends ConsumerStatefulWidget {
  final String? preselectedCustomerId;

  const _ReceivePaymentDialog({this.preselectedCustomerId});

  @override
  ConsumerState<_ReceivePaymentDialog> createState() =>
      _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState extends ConsumerState<_ReceivePaymentDialog> {
  String? _selectedCustomerId;
  String? _selectedSaleId;
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.preselectedCustomerId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(outstandingCustomersProvider);
    final paymentState = ref.watch(paymentCollectionProvider);

    // Watch outstanding sales if customer selected
    final outstandingSalesAsync = _selectedCustomerId != null
        ? ref.watch(customerOutstandingSalesProvider(_selectedCustomerId!))
        : null;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500),
      title: const Text('Receive Payment'),
      content: paymentState.isSuccess
          ? _buildSuccessContent(paymentState)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer selection
                InfoLabel(
                  label: 'Customer *',
                  child: customersAsync.when(
                    data: (customers) => ComboBox<String>(
                      value: _selectedCustomerId,
                      placeholder: const Text('Select customer'),
                      items: customers
                          .map((c) => ComboBoxItem(
                                value: c.id,
                                child: Text(
                                    '${c.name} (${Formatters.currency(c.creditBalance)})'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCustomerId = value;
                          _selectedSaleId = null;
                        });
                      },
                      isExpanded: true,
                    ),
                    loading: () => const ProgressRing(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ),
                const SizedBox(height: 16),

                // Sale selection (optional)
                if (_selectedCustomerId != null && outstandingSalesAsync != null)
                  InfoLabel(
                    label: 'Against Invoice (Optional)',
                    child: outstandingSalesAsync.when(
                      data: (sales) => ComboBox<String?>(
                        value: _selectedSaleId,
                        placeholder: const Text('General payment'),
                        items: [
                          const ComboBoxItem<String?>(
                            value: null,
                            child: Text('General payment'),
                          ),
                          ...sales.map((s) => ComboBoxItem(
                                value: s.sale.id,
                                child: Text(
                                    '${s.invoiceNumber} - ${Formatters.currency(s.outstandingAmount)}'),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSaleId = value);
                          // Auto-fill amount if invoice selected
                          if (value != null) {
                            final sale = sales.firstWhere((s) => s.sale.id == value);
                            _amountController.text =
                                sale.outstandingAmount.toStringAsFixed(2);
                          }
                        },
                        isExpanded: true,
                      ),
                      loading: () => const ProgressRing(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ),
                const SizedBox(height: 16),

                // Amount
                InfoLabel(
                  label: 'Amount *',
                  child: TextBox(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    placeholder: '0.00',
                  ),
                ),
                const SizedBox(height: 16),

                // Payment method
                InfoLabel(
                  label: 'Payment Method',
                  child: ComboBox<PaymentMethod>(
                    value: _paymentMethod,
                    items: PaymentMethod.values
                        .where((m) => m != PaymentMethod.credit)
                        .map((m) => ComboBoxItem(
                              value: m,
                              child: Text(m.displayName),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _paymentMethod = value);
                    },
                    isExpanded: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Reference number
                if (_paymentMethod != PaymentMethod.cash)
                  InfoLabel(
                    label: 'Reference Number',
                    child: TextBox(
                      controller: _referenceController,
                      placeholder: 'Cheque/Transfer reference',
                    ),
                  ),
                const SizedBox(height: 16),

                // Notes
                InfoLabel(
                  label: 'Notes',
                  child: TextBox(
                    controller: _notesController,
                    maxLines: 2,
                    placeholder: 'Optional notes',
                  ),
                ),

                if (paymentState.error != null) ...[
                  const SizedBox(height: 16),
                  InfoBar(
                    title: const Text('Error'),
                    content: Text(paymentState.error!),
                    severity: InfoBarSeverity.error,
                  ),
                ],
              ],
            ),
      actions: paymentState.isSuccess
          ? [
              FilledButton(
                child: const Text('Done'),
                onPressed: () {
                  ref.read(paymentCollectionProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
              ),
            ]
          : [
              Button(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              FilledButton(
                onPressed: paymentState.isProcessing ? null : _savePayment,
                child: paymentState.isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Text('Record Payment'),
              ),
            ],
    );
  }

  Widget _buildSuccessContent(PaymentCollectionState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.completed_solid, size: 48, color: AppTheme.successColor),
        const SizedBox(height: 16),
        const Text('Payment Recorded Successfully',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
            'Amount: ${Formatters.currency(state.completedTransaction?.amount ?? 0)}'),
      ],
    );
  }

  void _savePayment() {
    if (_selectedCustomerId == null) {
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      return;
    }

    ref.read(paymentCollectionProvider.notifier).recordPayment(
          customerId: _selectedCustomerId!,
          amount: amount,
          paymentMethod: _paymentMethod,
          saleId: _selectedSaleId,
          referenceNumber: _referenceController.text.isNotEmpty
              ? _referenceController.text
              : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
  }
}

// ==================== Aging Report Dialog ====================

class _AgingReportDialog extends ConsumerWidget {
  const _AgingReportDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agingAsync = ref.watch(agingSummaryProvider);
    final agingByCustomerAsync = ref.watch(agingByCustomerProvider);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
      title: const Text('Aging Report'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          agingAsync.when(
            data: (aging) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AgingBucket(
                      label: 'Current\n(0-30 days)',
                      amount: aging.current,
                      color: AppTheme.successColor,
                    ),
                    _AgingBucket(
                      label: '31-60\ndays',
                      amount: aging.days1to30,
                      color: AppTheme.warningColor,
                    ),
                    _AgingBucket(
                      label: '61-90\ndays',
                      amount: aging.days31to60,
                      color: Colors.orange,
                    ),
                    _AgingBucket(
                      label: '90+\ndays',
                      amount: aging.over90,
                      color: AppTheme.errorColor,
                    ),
                    _AgingBucket(
                      label: 'Total',
                      amount: aging.total,
                      color: AppTheme.primaryColor,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),

          // Detail by customer
          Text('By Customer', style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 8),
          Expanded(
            child: agingByCustomerAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return const Center(child: Text('No outstanding balances'));
                }
                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return ListTile(
                      title: Text(customer.customerName),
                      subtitle: Row(
                        children: [
                          _AgingMini('0-30', customer.current),
                          _AgingMini('31-60', customer.days1to30),
                          _AgingMini('61-90', customer.days31to60),
                          _AgingMini('90+', customer.over90),
                        ],
                      ),
                      trailing: Text(
                        Formatters.currency(customer.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _AgingBucket extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isTotal;

  const _AgingBucket({
    required this.label,
    required this.amount,
    required this.color,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[100],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          Formatters.currency(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            fontSize: isTotal ? 16 : 14,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AgingMini extends StatelessWidget {
  final String label;
  final double amount;

  const _AgingMini(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        '$label: ${Formatters.currency(amount)}',
        style: TextStyle(fontSize: 10, color: Colors.grey[100]),
      ),
    );
  }
}
