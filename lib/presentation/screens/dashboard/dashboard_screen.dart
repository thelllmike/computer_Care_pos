import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/inventory/inventory_provider.dart';
import '../../providers/repairs/repair_provider.dart';
import '../../providers/sales/sales_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _refreshDashboard(WidgetRef ref) {
    ref.invalidate(salesSummaryProvider(DateRange.today()));
    ref.invalidate(repairSummaryProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(todaysSalesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesSummaryAsync = ref.watch(salesSummaryProvider(DateRange.today()));
    final repairSummaryAsync = ref.watch(repairSummaryProvider);
    final lowStockAsync = ref.watch(lowStockProvider);
    final todaysSalesAsync = ref.watch(todaysSalesProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Dashboard'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () => _refreshDashboard(ref),
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
              Row(
                children: [
                  Expanded(
                    child: salesSummaryAsync.when(
                      data: (summary) => _SummaryCard(
                        title: "Today's Sales",
                        value: Formatters.currency(summary.totalRevenue),
                        icon: FluentIcons.money,
                        color: AppTheme.successColor,
                      ),
                      loading: () => const _SummaryCard(
                        title: "Today's Sales",
                        value: '...',
                        icon: FluentIcons.money,
                        color: AppTheme.successColor,
                      ),
                      error: (_, __) => const _SummaryCard(
                        title: "Today's Sales",
                        value: 'Error',
                        icon: FluentIcons.money,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: salesSummaryAsync.when(
                      data: (summary) => _SummaryCard(
                        title: "Today's Profit",
                        value: Formatters.currency(summary.totalProfit),
                        icon: FluentIcons.chart,
                        color: AppTheme.primaryColor,
                      ),
                      loading: () => const _SummaryCard(
                        title: "Today's Profit",
                        value: '...',
                        icon: FluentIcons.chart,
                        color: AppTheme.primaryColor,
                      ),
                      error: (_, __) => const _SummaryCard(
                        title: "Today's Profit",
                        value: 'Error',
                        icon: FluentIcons.chart,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: repairSummaryAsync.when(
                      data: (summary) => _SummaryCard(
                        title: 'Pending Repairs',
                        value: summary.pendingJobs.toString(),
                        icon: FluentIcons.repair,
                        color: AppTheme.warningColor,
                      ),
                      loading: () => const _SummaryCard(
                        title: 'Pending Repairs',
                        value: '...',
                        icon: FluentIcons.repair,
                        color: AppTheme.warningColor,
                      ),
                      error: (_, __) => const _SummaryCard(
                        title: 'Pending Repairs',
                        value: 'Error',
                        icon: FluentIcons.repair,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: lowStockAsync.when(
                      data: (items) => _SummaryCard(
                        title: 'Low Stock Items',
                        value: items.length.toString(),
                        icon: FluentIcons.warning,
                        color: AppTheme.errorColor,
                      ),
                      loading: () => const _SummaryCard(
                        title: 'Low Stock Items',
                        value: '...',
                        icon: FluentIcons.warning,
                        color: AppTheme.errorColor,
                      ),
                      error: (_, __) => const _SummaryCard(
                        title: 'Low Stock Items',
                        value: 'Error',
                        icon: FluentIcons.warning,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Recent transactions
              Text(
                'Recent Transactions',
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const SizedBox(height: 16),
              todaysSalesAsync.when(
                data: (sales) => sales.isEmpty
                    ? Card(
                        child: SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FluentIcons.document,
                                  size: 48,
                                  color: Colors.grey[100],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style: TextStyle(color: Colors.grey[100]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Card(
                        child: SizedBox(
                          height: 300,
                          child: ListView.builder(
                            itemCount: sales.length > 10 ? 10 : sales.length,
                            itemBuilder: (context, index) {
                              final sale = sales[index];
                              return ListTile.selectable(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    FluentIcons.shopping_cart,
                                    color: AppTheme.successColor,
                                    size: 16,
                                  ),
                                ),
                                title: Text(sale.sale.invoiceNumber),
                                subtitle: Text(
                                  sale.customer?.name ?? 'Walk-in Customer',
                                ),
                                trailing: Text(
                                  Formatters.currency(sale.sale.totalAmount),
                                  style: FluentTheme.of(context).typography.bodyStrong,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                loading: () => const Card(
                  child: SizedBox(
                    height: 300,
                    child: Center(child: ProgressRing()),
                  ),
                ),
                error: (e, _) => Card(
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Text('Error loading transactions: $e'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: Colors.grey[100],
                      ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: FluentTheme.of(context).typography.title?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
