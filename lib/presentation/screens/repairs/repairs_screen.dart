import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RepairsScreen extends ConsumerWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Repair Jobs'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Job Card'),
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
                      placeholder: 'Search by job number or customer...',
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
                      ComboBoxItem(value: 'received', child: Text('Received')),
                      ComboBoxItem(value: 'diagnosing', child: Text('Diagnosing')),
                      ComboBoxItem(value: 'in_progress', child: Text('In Progress')),
                      ComboBoxItem(value: 'completed', child: Text('Completed')),
                      ComboBoxItem(value: 'ready', child: Text('Ready for Pickup')),
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
                        Icon(FluentIcons.repair, size: 48, color: Colors.grey[100]),
                        const SizedBox(height: 16),
                        Text('No repair jobs', style: TextStyle(color: Colors.grey[100])),
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
