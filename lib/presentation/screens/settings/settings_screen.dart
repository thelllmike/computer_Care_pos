import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _receiptFooterController = TextEditingController();

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final settingsAsync = ref.read(settingsNotifierProvider);
    settingsAsync.whenData((settings) {
      _companyNameController.text = settings.name;
      _addressController.text = settings.address;
      _phoneController.text = settings.phone;
      _emailController.text = settings.email;
      _receiptFooterController.text = settings.receiptFooter ?? '';
    });
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final settings = CompanySettings(
      name: _companyNameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      receiptFooter: _receiptFooterController.text.trim().isEmpty
          ? null
          : _receiptFooterController.text.trim(),
    );

    final success = await ref.read(settingsNotifierProvider.notifier).saveCompanySettings(settings);

    setState(() {
      _isLoading = false;
      _hasChanges = false;
    });

    if (mounted) {
      if (success) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Settings saved successfully'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      } else {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Failed to save settings'),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    // Update controllers when settings load
    ref.listen(settingsNotifierProvider, (previous, next) {
      next.whenData((settings) {
        if (_companyNameController.text.isEmpty) {
          _companyNameController.text = settings.name;
          _addressController.text = settings.address;
          _phoneController.text = settings.phone;
          _emailController.text = settings.email;
          _receiptFooterController.text = settings.receiptFooter ?? '';
        }
      });
    });

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Settings'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            if (_hasChanges)
              CommandBarButton(
                icon: const Icon(FluentIcons.save),
                label: const Text('Save Changes'),
                onPressed: _isLoading ? null : _saveSettings,
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
              Text('Company Information', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: settingsAsync.when(
                    data: (_) => Column(
                      children: [
                        InfoLabel(
                          label: 'Company Name',
                          child: TextBox(
                            controller: _companyNameController,
                            placeholder: 'Enter company name',
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InfoLabel(
                          label: 'Address',
                          child: TextBox(
                            controller: _addressController,
                            placeholder: 'Enter address',
                            maxLines: 2,
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InfoLabel(
                                label: 'Phone',
                                child: TextBox(
                                  controller: _phoneController,
                                  placeholder: 'Phone number',
                                  onChanged: (_) => _onFieldChanged(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoLabel(
                                label: 'Email',
                                child: TextBox(
                                  controller: _emailController,
                                  placeholder: 'Email address',
                                  onChanged: (_) => _onFieldChanged(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        InfoLabel(
                          label: 'Receipt Footer Message',
                          child: TextBox(
                            controller: _receiptFooterController,
                            placeholder: 'Thank you for your business!',
                            maxLines: 2,
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton(
                              onPressed: _isLoading ? null : _saveSettings,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: ProgressRing(strokeWidth: 2),
                                    )
                                  : const Text('Save Settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    loading: () => const Center(child: ProgressRing()),
                    error: (e, _) => Center(
                      child: Text('Error loading settings: $e'),
                    ),
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
                            onPressed: () {
                              // TODO: Implement printer configuration
                              displayInfoBar(
                                context,
                                builder: (context, close) => InfoBar(
                                  title: const Text('Printer configuration coming soon'),
                                  severity: InfoBarSeverity.info,
                                  onClose: close,
                                ),
                              );
                            },
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
                            onPressed: () {
                              displayInfoBar(
                                context,
                                builder: (context, close) => InfoBar(
                                  title: const Text('Printer configuration coming soon'),
                                  severity: InfoBarSeverity.info,
                                  onClose: close,
                                ),
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
                            onPressed: () {
                              displayInfoBar(
                                context,
                                builder: (context, close) => InfoBar(
                                  title: const Text('Sync feature coming soon'),
                                  severity: InfoBarSeverity.info,
                                  onClose: close,
                                ),
                              );
                            },
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
                            onPressed: () {
                              displayInfoBar(
                                context,
                                builder: (context, close) => InfoBar(
                                  title: const Text('Export feature coming soon'),
                                  severity: InfoBarSeverity.info,
                                  onClose: close,
                                ),
                              );
                            },
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
