import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/credits/credit_provider.dart';
import '../../providers/expenses/expense_provider.dart';
import '../../providers/inventory/inventory_provider.dart';
import '../../providers/repairs/repair_provider.dart';
import '../../providers/sales/sales_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selectedReport;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Reports'),
        commandBar: _selectedReport != null
            ? CommandBar(
                mainAxisAlignment: MainAxisAlignment.end,
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.back),
                    label: const Text('Back to Reports'),
                    onPressed: () => setState(() => _selectedReport = null),
                  ),
                ],
              )
            : null,
      ),
      content: _selectedReport == null
          ? _buildReportsList()
          : _buildReportContent(_selectedReport!),
    );
  }

  Widget _buildReportsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _ReportCard(
            title: 'Sales Report',
            description: 'Daily, weekly, monthly sales analysis',
            icon: FluentIcons.chart,
            onTap: () => setState(() => _selectedReport = 'sales'),
          ),
          _ReportCard(
            title: 'Profit & Loss',
            description: 'Revenue, costs, and profit margins',
            icon: FluentIcons.calculator,
            onTap: () => setState(() => _selectedReport = 'profit'),
          ),
          _ReportCard(
            title: 'Inventory Valuation',
            description: 'Stock value based on WAC',
            icon: FluentIcons.archive,
            onTap: () => setState(() => _selectedReport = 'inventory'),
          ),
          _ReportCard(
            title: 'Aging Report',
            description: 'Credit aging by 30/60/90+ days',
            icon: FluentIcons.calendar,
            onTap: () => setState(() => _selectedReport = 'aging'),
          ),
          _ReportCard(
            title: 'Repair Summary',
            description: 'Repair jobs and revenue',
            icon: FluentIcons.repair,
            onTap: () => setState(() => _selectedReport = 'repairs'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(String reportType) {
    switch (reportType) {
      case 'sales':
        return const _SalesReportContent();
      case 'profit':
        return const _ProfitReportContent();
      case 'inventory':
        return const _InventoryReportContent();
      case 'aging':
        return const _AgingReportContent();
      case 'repairs':
        return const _RepairReportContent();
      default:
        return const Center(child: Text('Report not found'));
    }
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Button(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(EdgeInsets.zero),
          ),
          onPressed: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Sales Report Content
class _SalesReportContent extends ConsumerStatefulWidget {
  const _SalesReportContent();

  @override
  ConsumerState<_SalesReportContent> createState() => _SalesReportContentState();
}

class _SalesReportContentState extends ConsumerState<_SalesReportContent> {
  String _period = 'today';

  DateRange _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return DateRange.today();
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'month':
        return DateRange.thisMonth();
      case 'year':
        return DateRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      default:
        return DateRange.today();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(salesSummaryProvider(_getDateRange()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              ComboBox<String>(
                value: _period,
                items: const [
                  ComboBoxItem(value: 'today', child: Text('Today')),
                  ComboBoxItem(value: 'week', child: Text('This Week')),
                  ComboBoxItem(value: 'month', child: Text('This Month')),
                  ComboBoxItem(value: 'year', child: Text('This Year')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _period = value);
                },
              ),
              const SizedBox(width: 16),
              Button(
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
                onPressed: () => ref.invalidate(salesSummaryProvider(_getDateRange())),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Summary cards
          summaryAsync.when(
            data: (summary) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Sales',
                        value: summary.totalSales.toString(),
                        subtitle: 'transactions',
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Revenue',
                        value: Formatters.currency(summary.totalRevenue),
                        subtitle: 'total revenue',
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Cost',
                        value: Formatters.currency(summary.totalCost),
                        subtitle: 'total cost',
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Profit',
                        value: Formatters.currency(summary.totalProfit),
                        subtitle: '${summary.profitMargin.toStringAsFixed(1)}% margin',
                        color: summary.totalProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Credit Sales',
                        value: Formatters.currency(summary.totalCreditOutstanding),
                        subtitle: 'outstanding',
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

// Profit Report Content
class _ProfitReportContent extends ConsumerStatefulWidget {
  const _ProfitReportContent();

  @override
  ConsumerState<_ProfitReportContent> createState() => _ProfitReportContentState();
}

class _ProfitReportContentState extends ConsumerState<_ProfitReportContent> {
  String _period = 'month';

  DateRange _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return DateRange.today();
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'month':
        return DateRange.thisMonth();
      case 'year':
        return DateRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      default:
        return DateRange.thisMonth();
    }
  }

  DateRangeParams _getExpenseDateRange() {
    final range = _getDateRange();
    return DateRangeParams(startDate: range.start, endDate: range.end);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(salesSummaryProvider(_getDateRange()));
    final expenseAsync = ref.watch(expenseSummaryProvider(_getExpenseDateRange()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ComboBox<String>(
                value: _period,
                items: const [
                  ComboBoxItem(value: 'today', child: Text('Today')),
                  ComboBoxItem(value: 'week', child: Text('This Week')),
                  ComboBoxItem(value: 'month', child: Text('This Month')),
                  ComboBoxItem(value: 'year', child: Text('This Year')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _period = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          summaryAsync.when(
            data: (summary) {
              return expenseAsync.when(
                data: (expenseSummary) {
                  final totalExpenses = expenseSummary.totalAmount;
                  final netProfit = summary.totalProfit - totalExpenses;
                  final netProfitMargin = summary.totalRevenue > 0
                      ? (netProfit / summary.totalRevenue) * 100
                      : 0.0;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profit & Loss Summary', style: FluentTheme.of(context).typography.subtitle),
                          const SizedBox(height: 24),

                          // Revenue Section
                          Text('REVENUE', style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _ProfitRow(label: 'Sales Revenue', value: summary.totalRevenue, isPositive: true),
                          const Divider(),

                          // Cost of Goods Section
                          const SizedBox(height: 8),
                          Text('COST OF GOODS SOLD', style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _ProfitRow(label: 'Cost of Goods Sold', value: summary.totalCost, isPositive: false),
                          const Divider(),

                          // Gross Profit
                          _ProfitRow(
                            label: 'Gross Profit',
                            value: summary.totalProfit,
                            isPositive: summary.totalProfit >= 0,
                            isBold: true,
                          ),
                          const Divider(),

                          // Operating Expenses Section
                          const SizedBox(height: 8),
                          Text('OPERATING EXPENSES', style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),

                          // Show expense breakdown by category
                          if (expenseSummary.categoryBreakdown.isNotEmpty) ...[
                            ...expenseSummary.categoryBreakdown.entries.map((entry) {
                              return _ProfitRow(
                                label: '  ${_getCategoryDisplayName(entry.key)}',
                                value: entry.value,
                                isPositive: false,
                              );
                            }),
                          ] else ...[
                            _ProfitRow(label: '  No expenses recorded', value: 0, isPositive: false),
                          ],

                          _ProfitRow(
                            label: 'Total Expenses',
                            value: totalExpenses,
                            isPositive: false,
                            isBold: true,
                          ),
                          const Divider(),

                          // Net Profit Section
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: netProfit >= 0
                                  ? AppTheme.successColor.withValues(alpha: 0.1)
                                  : AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _ProfitRow(
                                  label: 'NET PROFIT',
                                  value: netProfit,
                                  isPositive: netProfit >= 0,
                                  isBold: true,
                                ),
                                const SizedBox(height: 8),
                                _ProfitRow(
                                  label: 'Net Profit Margin',
                                  value: netProfitMargin,
                                  isPercentage: true,
                                  isPositive: netProfitMargin >= 0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: ProgressRing()),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profit & Loss Summary', style: FluentTheme.of(context).typography.subtitle),
                        const SizedBox(height: 24),
                        _ProfitRow(label: 'Revenue', value: summary.totalRevenue, isPositive: true),
                        const Divider(),
                        _ProfitRow(label: 'Cost of Goods Sold', value: summary.totalCost, isPositive: false),
                        const Divider(),
                        _ProfitRow(
                          label: 'Gross Profit',
                          value: summary.totalProfit,
                          isPositive: summary.totalProfit >= 0,
                          isBold: true,
                        ),
                        const Divider(),
                        InfoBar(
                          title: const Text('Expenses'),
                          content: const Text('Unable to load expenses'),
                          severity: InfoBarSeverity.warning,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(String code) {
    const categoryNames = {
      'ELECTRICITY': 'Electricity',
      'WATER': 'Water',
      'RENT': 'Rent',
      'INTERNET': 'Internet',
      'TELEPHONE': 'Telephone',
      'SALARY': 'Salary',
      'SUPPLIES': 'Office Supplies',
      'MAINTENANCE': 'Maintenance',
      'TRANSPORT': 'Transport',
      'OTHER': 'Other Expenses',
    };
    return categoryNames[code] ?? code;
  }
}

class _ProfitRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isPositive;
  final bool isBold;
  final bool isPercentage;

  const _ProfitRow({
    required this.label,
    required this.value,
    required this.isPositive,
    this.isBold = false,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold ? FluentTheme.of(context).typography.bodyStrong : null,
          ),
          Text(
            isPercentage ? '${value.toStringAsFixed(1)}%' : Formatters.currency(value),
            style: FluentTheme.of(context).typography.body?.copyWith(
                  color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                  fontWeight: isBold ? FontWeight.bold : null,
                ),
          ),
        ],
      ),
    );
  }
}

// Inventory Report Content
class _InventoryReportContent extends ConsumerWidget {
  const _InventoryReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(inventoryStatsProvider);
    final inventoryAsync = ref.watch(inventoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Products',
                    value: stats.totalProducts.toString(),
                    subtitle: 'items',
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Total Value',
                    value: Formatters.currency(stats.totalValue),
                    subtitle: 'inventory value',
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Low Stock',
                    value: stats.lowStockCount.toString(),
                    subtitle: 'items need reorder',
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Serialized Items',
                    value: stats.serializedCount.toString(),
                    subtitle: 'in stock',
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),
          // Inventory list
          Text('Inventory Details', style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 16),
          inventoryAsync.when(
            data: (items) => Card(
              child: SizedBox(
                height: 400,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile.selectable(
                      title: Text(item.product.name),
                      subtitle: Text(item.product.code),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Qty: ${item.quantityOnHand}'),
                              Text(
                                Formatters.currency(item.totalCost),
                                style: FluentTheme.of(context).typography.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

// Aging Report Content
class _AgingReportContent extends ConsumerWidget {
  const _AgingReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(creditSummaryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summaryAsync.when(
            data: (summary) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Outstanding',
                        value: Formatters.currency(summary.totalOutstanding),
                        subtitle: 'credit balance',
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Credit Customers',
                        value: summary.creditCustomersCount.toString(),
                        subtitle: 'with balance',
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Overdue Amount',
                        value: Formatters.currency(summary.overdueAmount),
                        subtitle: 'past due',
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Collected This Month',
                        value: Formatters.currency(summary.collectedThisMonth),
                        subtitle: 'payments received',
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credit Summary', style: FluentTheme.of(context).typography.subtitle),
                        const SizedBox(height: 16),
                        _AgingRow(label: 'Total Outstanding', value: summary.totalOutstanding, color: AppTheme.primaryColor),
                        _AgingRow(label: 'Overdue Amount', value: summary.overdueAmount, color: AppTheme.errorColor),
                        _AgingRow(label: 'Collected This Month', value: summary.collectedThisMonth, color: AppTheme.successColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

class _AgingRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AgingRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            Formatters.currency(value),
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
        ],
      ),
    );
  }
}

// Repair Report Content
class _RepairReportContent extends ConsumerWidget {
  const _RepairReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(repairSummaryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summaryAsync.when(
            data: (summary) => Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Active Jobs',
                    value: summary.activeJobs.toString(),
                    subtitle: 'in progress',
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Pending Jobs',
                    value: summary.pendingJobs.toString(),
                    subtitle: 'awaiting',
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Completed Today',
                    value: summary.completedToday.toString(),
                    subtitle: 'jobs',
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Revenue',
                    value: Formatters.currency(summary.totalRevenue),
                    subtitle: 'from repairs',
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: Colors.grey[100],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: FluentTheme.of(context).typography.title?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: FluentTheme.of(context).typography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
