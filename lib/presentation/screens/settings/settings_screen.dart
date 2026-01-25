import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/core/settings_provider.dart';
import '../../providers/core/sync_provider.dart';

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
              Text('Data Sync', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              _SyncStatusCard(),
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

class _SyncStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: syncState.isOnline ? AppTheme.successColor : AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  syncState.isOnline ? 'Online' : 'Offline',
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: syncState.isOnline ? AppTheme.successColor : AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (syncState.pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${syncState.pendingCount} pending',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Last sync time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Synced',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                            color: Colors.grey[100],
                          ),
                    ),
                    Text(
                      syncState.lastSyncAt != null
                          ? Formatters.dateTime(syncState.lastSyncAt!)
                          : 'Never',
                      style: FluentTheme.of(context).typography.body,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Button(
                      child: const Row(
                        children: [
                          Icon(FluentIcons.download, size: 14),
                          SizedBox(width: 4),
                          Text('Pull'),
                        ],
                      ),
                      onPressed: syncState.isSyncing
                          ? null
                          : () async {
                              final result = await ref.read(syncProvider.notifier).pullChanges();
                              if (context.mounted) {
                                displayInfoBar(
                                  context,
                                  builder: (context, close) => InfoBar(
                                    title: Text(result.success
                                        ? 'Pulled ${result.pulledCount} records'
                                        : 'Pull failed'),
                                    content: result.errors.isNotEmpty
                                        ? Text(result.errors.first)
                                        : null,
                                    severity: result.success
                                        ? InfoBarSeverity.success
                                        : InfoBarSeverity.error,
                                    onClose: close,
                                  ),
                                );
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    Button(
                      child: const Row(
                        children: [
                          Icon(FluentIcons.upload, size: 14),
                          SizedBox(width: 4),
                          Text('Push'),
                        ],
                      ),
                      onPressed: syncState.isSyncing
                          ? null
                          : () async {
                              final result = await ref.read(syncProvider.notifier).pushChanges();
                              if (context.mounted) {
                                displayInfoBar(
                                  context,
                                  builder: (context, close) => InfoBar(
                                    title: Text(result.success
                                        ? 'Pushed ${result.pushedCount} records'
                                        : 'Push failed'),
                                    content: result.errors.isNotEmpty
                                        ? Text(result.errors.first)
                                        : null,
                                    severity: result.success
                                        ? InfoBarSeverity.success
                                        : InfoBarSeverity.error,
                                    onClose: close,
                                  ),
                                );
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: syncState.isSyncing
                          ? null
                          : () async {
                              final result = await ref.read(syncProvider.notifier).syncNow();
                              if (context.mounted) {
                                displayInfoBar(
                                  context,
                                  builder: (context, close) => InfoBar(
                                    title: Text(result.success
                                        ? 'Sync complete: ${result.pushedCount} pushed, ${result.pulledCount} pulled'
                                        : 'Sync failed'),
                                    content: result.errors.isNotEmpty
                                        ? Text(result.errors.first)
                                        : null,
                                    severity: result.success
                                        ? InfoBarSeverity.success
                                        : InfoBarSeverity.error,
                                    onClose: close,
                                  ),
                                );
                              }
                            },
                      child: syncState.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: ProgressRing(strokeWidth: 2),
                            )
                          : const Row(
                              children: [
                                Icon(FluentIcons.sync, size: 14),
                                SizedBox(width: 4),
                                Text('Sync All'),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),
            // Error message
            if (syncState.lastError != null) ...[
              const SizedBox(height: 12),
              InfoBar(
                title: const Text('Sync Error'),
                content: Text(syncState.lastError!),
                severity: InfoBarSeverity.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
