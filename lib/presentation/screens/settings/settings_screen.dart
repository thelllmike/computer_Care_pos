import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/core/database_provider.dart';
import '../../providers/core/settings_provider.dart';
import '../../providers/core/sync_provider.dart';
import '../../providers/core/theme_provider.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/enums/user_role.dart';
import '../../../services/backup/backup_service.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';

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
  final _bankNameController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankBranchController = TextEditingController();

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
    _bankNameController.dispose();
    _bankAccountNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankBranchController.dispose();
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
      _bankNameController.text = settings.bankName ?? '';
      _bankAccountNameController.text = settings.bankAccountName ?? '';
      _bankAccountNumberController.text = settings.bankAccountNumber ?? '';
      _bankBranchController.text = settings.bankBranch ?? '';
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
      bankName: _bankNameController.text.trim().isEmpty
          ? null
          : _bankNameController.text.trim(),
      bankAccountName: _bankAccountNameController.text.trim().isEmpty
          ? null
          : _bankAccountNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty
          ? null
          : _bankAccountNumberController.text.trim(),
      bankBranch: _bankBranchController.text.trim().isEmpty
          ? null
          : _bankBranchController.text.trim(),
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
          _bankNameController.text = settings.bankName ?? '';
          _bankAccountNameController.text = settings.bankAccountName ?? '';
          _bankAccountNumberController.text = settings.bankAccountNumber ?? '';
          _bankBranchController.text = settings.bankBranch ?? '';
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
              Text('Appearance', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              const _AppearanceCard(),
              const SizedBox(height: 32),
              if (ref.watch(authNotifierProvider).role == UserRole.admin) ...[
                Text('Backup & Restore', style: FluentTheme.of(context).typography.subtitle),
                const SizedBox(height: 16),
                const _BackupCard(),
                const SizedBox(height: 32),
              ],
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
              Text('Bank Account Information', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: settingsAsync.when(
                    data: (_) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InfoLabel(
                                label: 'Bank Name',
                                child: TextBox(
                                  controller: _bankNameController,
                                  placeholder: 'e.g. Commercial Bank PLC',
                                  onChanged: (_) => _onFieldChanged(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoLabel(
                                label: 'Branch',
                                child: TextBox(
                                  controller: _bankBranchController,
                                  placeholder: 'e.g. Akuressa Branch',
                                  onChanged: (_) => _onFieldChanged(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InfoLabel(
                                label: 'Account Name',
                                child: TextBox(
                                  controller: _bankAccountNameController,
                                  placeholder: 'e.g. A P M Prasad',
                                  onChanged: (_) => _onFieldChanged(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoLabel(
                                label: 'Account Number',
                                child: TextBox(
                                  controller: _bankAccountNumberController,
                                  placeholder: 'e.g. 8013595841',
                                  onChanged: (_) => _onFieldChanged(),
                                ),
                              ),
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

// Provider for local sales count (for debugging)
final localSalesCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.salesDao.getTotalSalesCount();
});

class _SyncStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final localSalesCount = ref.watch(localSalesCountProvider);

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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Button(
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
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
                    Button(
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.sync, size: 14),
                                SizedBox(width: 4),
                                Text('Sync All'),
                              ],
                            ),
                    ),
                    Button(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(AppTheme.warningColor.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.refresh, size: 14, color: AppTheme.warningColor),
                          const SizedBox(width: 4),
                          Text('Force Full Sync', style: TextStyle(color: AppTheme.warningColor)),
                        ],
                      ),
                      onPressed: syncState.isSyncing
                          ? null
                          : () async {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => ContentDialog(
                                  title: const Text('Force Full Sync'),
                                  content: const Text(
                                    'This will reset sync timestamps and pull ALL data from Supabase. '
                                    'Use this if your local data is out of sync.\n\n'
                                    'Your local pending changes will be pushed first.',
                                  ),
                                  actions: [
                                    Button(
                                      child: const Text('Cancel'),
                                      onPressed: () => Navigator.of(context).pop(false),
                                    ),
                                    FilledButton(
                                      child: const Text('Force Full Sync'),
                                      onPressed: () => Navigator.of(context).pop(true),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                final result = await ref.read(syncProvider.notifier).forceFullSync();
                                if (context.mounted) {
                                  displayInfoBar(
                                    context,
                                    builder: (context, close) => InfoBar(
                                      title: Text(result.success
                                          ? 'Full sync complete: ${result.pushedCount} pushed, ${result.pulledCount} pulled'
                                          : 'Full sync failed'),
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
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
            // Local data count (debug)
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Local Sales Count: ',
                  style: FluentTheme.of(context).typography.caption,
                ),
                localSalesCount.when(
                  data: (count) => Text(
                    count.toString(),
                    style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  loading: () => const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2)),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(width: 8),
                Button(
                  child: const Text('Refresh'),
                  onPressed: () => ref.invalidate(localSalesCountProvider),
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

// Appearance (theme) settings
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeChoice = ref.watch(themeModeProvider);

    Widget option(AppThemeChoice mode, IconData icon, String label) {
      return Padding(
        padding: const EdgeInsets.only(right: 24),
        child: RadioButton(
          checked: themeChoice == mode,
          onChanged: (checked) {
            if (checked) {
              ref.read(themeModeProvider.notifier).setTheme(mode);
            }
          },
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: InfoLabel(
          label: 'Theme',
          child: Wrap(
            runSpacing: 8,
            children: [
              option(AppThemeChoice.light, FluentIcons.sunny, 'Light'),
              option(AppThemeChoice.dark, FluentIcons.clear_night, 'Dark'),
              option(AppThemeChoice.clever, FluentIcons.color, 'Clever Project'),
              option(AppThemeChoice.system, FluentIcons.t_v_monitor, 'Use system setting'),
            ],
          ),
        ),
      ),
    );
  }
}

// Backup & Restore (export / import all data) - admin only
class _BackupCard extends ConsumerStatefulWidget {
  const _BackupCard();

  @override
  ConsumerState<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<_BackupCard> {
  bool _busy = false;

  static const _typeGroup = XTypeGroup(label: 'CP POS Backup', extensions: ['json']);

  BackupService get _service => BackupService(ref.read(databaseProvider));

  void _info(String title, String message, InfoBarSeverity severity) {
    if (!mounted) return;
    displayInfoBar(context, builder: (context, close) => InfoBar(
          title: Text(title),
          content: Text(message),
          severity: severity,
          onClose: close,
        ));
  }

  Future<void> _export() async {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final suggested =
        'cp_pos_backup_${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}${two(now.minute)}.json';

    final location = await getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: const [_typeGroup],
    );
    if (location == null) return;

    setState(() => _busy = true);
    try {
      final json = await _service.exportToJson();
      var path = location.path;
      if (!path.toLowerCase().endsWith('.json')) path = '$path.json';
      await File(path).writeAsString(json);
      _info('Export complete', 'All data saved to $path', InfoBarSeverity.success);
    } catch (e) {
      _info('Export failed', e.toString(), InfoBarSeverity.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null) return;

    final String json;
    final Map<String, int> summary;
    try {
      json = await file.readAsString();
      summary = _service.summarize(json);
    } catch (e) {
      _info('Cannot import', e is FormatException ? e.message : e.toString(),
          InfoBarSeverity.error);
      return;
    }

    final total = summary.values.fold<int>(0, (a, b) => a + b);
    final nonEmpty = summary.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Import backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${file.name}\n$total records in ${nonEmpty.length} tables.'),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  nonEmpty.map((e) => '${e.key}: ${e.value}').join('\n'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const InfoBar(
              title: Text('Records with the same ID will be overwritten'),
              content: Text(
                  'New records are added and nothing is deleted. Imported records '
                  'are uploaded to the cloud on the next sync, replacing the cloud copy. '
                  'Export a backup of the current data first if you are unsure.'),
              severity: InfoBarSeverity.warning,
              isLong: true,
            ),
          ],
        ),
        actions: [
          Button(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
          FilledButton(child: const Text('Import'), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await _service.importFromJson(json);
      ref.invalidate(settingsNotifierProvider);
      ref.invalidate(companySettingsProvider);
      _info(
        'Import complete',
        'Imported ${result.imported} records'
            '${result.skipped > 0 ? ', skipped ${result.skipped} (conflicting or invalid)' : ''}.',
        result.skipped > 0 ? InfoBarSeverity.warning : InfoBarSeverity.success,
      );
    } catch (e) {
      _info('Import failed', 'No changes were made. $e', InfoBarSeverity.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export saves all data (products, stock, customers, sales, repairs, '
              'expenses, settings…) to a single backup file. Import restores data '
              'from a backup file.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : _export,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(FluentIcons.download, size: 16),
                    SizedBox(width: 8),
                    Text('Export All Data'),
                  ]),
                ),
                const SizedBox(width: 12),
                Button(
                  onPressed: _busy ? null : _import,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(FluentIcons.upload, size: 16),
                    SizedBox(width: 8),
                    Text('Import Data'),
                  ]),
                ),
                if (_busy) ...[
                  const SizedBox(width: 16),
                  const SizedBox(width: 20, height: 20, child: ProgressRing(strokeWidth: 2.5)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
