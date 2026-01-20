import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Credit Management'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.money),
              label: const Text('Receive Payment'),
              onPressed: () {},
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
                    child: _SummaryCard(
                      title: 'Total Outstanding',
                      value: 'LKR 0.00',
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Overdue (30+ days)',
                      value: 'LKR 0.00',
                      color: AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Collected This Month',
                      value: 'LKR 0.00',
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Search
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      placeholder: 'Search by customer name or invoice...',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(FluentIcons.search, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Outstanding Receivables', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              Card(
                child: SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.money, size: 48, color: Colors.grey[100]),
                        const SizedBox(height: 16),
                        Text('No outstanding credits', style: TextStyle(color: Colors.grey[100])),
                      ],
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
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
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
            Text(title, style: FluentTheme.of(context).typography.body?.copyWith(color: Colors.grey[100])),
            const SizedBox(height: 8),
            Text(
              value,
              style: FluentTheme.of(context).typography.subtitle?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
