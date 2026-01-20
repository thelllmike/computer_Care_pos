import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(
        title: Text('Settings'),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Company Information', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const InfoLabel(
                        label: 'Company Name',
                        child: TextBox(placeholder: 'Enter company name'),
                      ),
                      const SizedBox(height: 16),
                      const InfoLabel(
                        label: 'Address',
                        child: TextBox(
                          placeholder: 'Enter address',
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: InfoLabel(
                              label: 'Phone',
                              child: TextBox(placeholder: 'Phone number'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: InfoLabel(
                              label: 'Email',
                              child: TextBox(placeholder: 'Email address'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Printer Settings', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Thermal Receipt Printer (80mm)'),
                          Button(
                            child: const Text('Configure'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('A4 Invoice Printer'),
                          Button(
                            child: const Text('Configure'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Data Management', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sync Status'),
                              Text(
                                'Last synced: Never',
                                style: FluentTheme.of(context).typography.caption,
                              ),
                            ],
                          ),
                          FilledButton(
                            child: const Text('Sync Now'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Export Data to Excel'),
                          Button(
                            child: const Text('Export'),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
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
