import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuotationsScreen extends ConsumerWidget {
  const QuotationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Quotations'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Quotation'),
              onPressed: () {},
            ),
          ],
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      placeholder: 'Search quotations...',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(FluentIcons.search, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ComboBox<String>(
                    placeholder: const Text('Status'),
                    items: const [
                      ComboBoxItem(value: 'all', child: Text('All')),
                      ComboBoxItem(value: 'draft', child: Text('Draft')),
                      ComboBoxItem(value: 'sent', child: Text('Sent')),
                      ComboBoxItem(value: 'accepted', child: Text('Accepted')),
                      ComboBoxItem(value: 'expired', child: Text('Expired')),
                    ],
                    onChanged: (value) {},
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.document, size: 48, color: Colors.grey[100]),
                        const SizedBox(height: 16),
                        Text('No quotations yet', style: TextStyle(color: Colors.grey[100])),
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
