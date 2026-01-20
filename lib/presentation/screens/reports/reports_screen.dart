import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(
        title: Text('Reports'),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ReportCard(
                title: 'Sales Report',
                description: 'Daily, weekly, monthly sales analysis',
                icon: FluentIcons.chart,
                onTap: () {},
              ),
              _ReportCard(
                title: 'Profit & Loss',
                description: 'Revenue, costs, and profit margins',
                icon: FluentIcons.trending_up,
                onTap: () {},
              ),
              _ReportCard(
                title: 'Inventory Valuation',
                description: 'Stock value based on WAC',
                icon: FluentIcons.warehouse_solid,
                onTap: () {},
              ),
              _ReportCard(
                title: 'Aging Report',
                description: 'Credit aging by 30/60/90+ days',
                icon: FluentIcons.calendar,
                onTap: () {},
              ),
              _ReportCard(
                title: 'Serial History',
                description: 'Track serial number movements',
                icon: FluentIcons.history,
                onTap: () {},
              ),
              _ReportCard(
                title: 'Repair Summary',
                description: 'Repair jobs and revenue',
                icon: FluentIcons.repair,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
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
