import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/warranty_claim_dao.dart';
import '../../../data/local/tables/warranty_claims_table.dart';
import '../../providers/warranty/warranty_claim_provider.dart';
import '../../providers/inventory/supplier_provider.dart';

class WarrantyClaimsScreen extends ConsumerStatefulWidget {
  const WarrantyClaimsScreen({super.key});

  @override
  ConsumerState<WarrantyClaimsScreen> createState() =>
      _WarrantyClaimsScreenState();
}

class _WarrantyClaimsScreenState extends ConsumerState<WarrantyClaimsScreen> {
  WarrantyClaimStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(warrantySummaryProvider);
    final claimsAsync = _selectedStatus == null
        ? ref.watch(warrantyClaimsProvider)
        : ref.watch(warrantyClaimsByStatusProvider(_selectedStatus!));

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Warranty Claims'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Claim'),
              onPressed: () => _showCreateClaimDialog(context, ref),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(warrantyClaimsProvider);
                ref.invalidate(activeWarrantyClaimsProvider);
                ref.invalidate(warrantySummaryProvider);
              },
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
              summaryAsync.when(
                data: (summary) => Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pending',
                        value: summary.pendingCount.toString(),
                        icon: FluentIcons.clock,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Sent to Supplier',
                        value: summary.sentToSupplierCount.toString(),
                        icon: FluentIcons.send,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'In Repair',
                        value: summary.inRepairCount.toString(),
                        icon: FluentIcons.repair,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Resolved',
                        value: summary.resolvedCount.toString(),
                        icon: FluentIcons.completed,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                loading: () => const Row(
                  children: [
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                    SizedBox(width: 16),
                    Expanded(child: _SummaryCardLoading()),
                  ],
                ),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Status filter
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.filter),
                      const SizedBox(width: 16),
                      const Text('Filter by Status: '),
                      const SizedBox(width: 8),
                      ComboBox<WarrantyClaimStatus?>(
                        placeholder: const Text('All Status'),
                        value: _selectedStatus,
                        items: [
                          const ComboBoxItem(
                              value: null, child: Text('All Status')),
                          ...WarrantyClaimStatus.values.map((s) => ComboBoxItem(
                                value: s,
                                child: Text(s.displayName),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Claims list
              Text('Warranty Claims',
                  style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 12),
              claimsAsync.when(
                data: (claims) {
                  if (claims.isEmpty) {
                    return Card(
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.certificate,
                                  size: 48, color: Colors.grey[100]),
                              const SizedBox(height: 16),
                              Text('No warranty claims found',
                                  style: TextStyle(color: Colors.grey[100])),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: Column(
                      children: claims
                          .map((claim) => _ClaimTile(
                                claim: claim,
                                onTap: () =>
                                    _showClaimDetailDialog(context, ref, claim),
                              ))
                          .toList(),
                    ),
                  );
                },
                loading: () => const Card(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: ProgressRing()),
                  ),
                ),
                error: (e, _) => Card(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: Text('Error: $e')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateClaimDialog(BuildContext context, WidgetRef ref) {
    ref.read(warrantyClaimFormProvider.notifier).clear();
    showDialog(
      context: context,
      builder: (context) => const _CreateClaimDialog(),
    );
  }

  void _showClaimDetailDialog(
      BuildContext context, WidgetRef ref, WarrantyClaimWithDetails claim) {
    showDialog(
      context: context,
      builder: (context) => _ClaimDetailDialog(claim: claim),
    );
  }
}

// Summary Card Widget
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(color: Colors.grey[100])),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: FluentTheme.of(context).typography.subtitle?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardLoading extends StatelessWidget {
  const _SummaryCardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: ProgressRing()),
      ),
    );
  }
}

// Claim Tile Widget
class _ClaimTile extends StatelessWidget {
  final WarrantyClaimWithDetails claim;
  final VoidCallback onTap;

  const _ClaimTile({required this.claim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getStatusColor(claim.status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(FluentIcons.certificate,
            color: _getStatusColor(claim.status), size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(claim.claimNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  claim.productName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                ),
              ],
            ),
          ),
          _StatusBadge(status: claim.status),
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            'S/N: ${claim.serialNumberString}',
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
          const SizedBox(width: 16),
          Text(
            'Supplier: ${claim.supplierName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
          const Spacer(),
          if (claim.daysPending > 0)
            Text(
              '${claim.daysPending} days',
              style: TextStyle(
                fontSize: 12,
                color: claim.daysPending > 30 ? Colors.red : Colors.grey[100],
                fontWeight:
                    claim.daysPending > 30 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
      onPressed: onTap,
    );
  }

  Color _getStatusColor(WarrantyClaimStatus status) {
    switch (status) {
      case WarrantyClaimStatus.pending:
        return Colors.orange;
      case WarrantyClaimStatus.sentToSupplier:
        return Colors.blue;
      case WarrantyClaimStatus.inRepair:
        return Colors.purple;
      case WarrantyClaimStatus.returned:
        return Colors.teal;
      case WarrantyClaimStatus.resolved:
        return Colors.green;
      case WarrantyClaimStatus.rejected:
        return Colors.red;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final WarrantyClaimStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case WarrantyClaimStatus.pending:
        color = Colors.orange;
        break;
      case WarrantyClaimStatus.sentToSupplier:
        color = Colors.blue;
        break;
      case WarrantyClaimStatus.inRepair:
        color = Colors.purple;
        break;
      case WarrantyClaimStatus.returned:
        color = Colors.teal;
        break;
      case WarrantyClaimStatus.resolved:
        color = Colors.green;
        break;
      case WarrantyClaimStatus.rejected:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Create Claim Dialog
class _CreateClaimDialog extends ConsumerStatefulWidget {
  const _CreateClaimDialog();

  @override
  ConsumerState<_CreateClaimDialog> createState() => _CreateClaimDialogState();
}

class _CreateClaimDialogState extends ConsumerState<_CreateClaimDialog> {
  final _reasonController = TextEditingController();
  String _serialSearchQuery = '';

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(warrantyClaimFormProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final serialsAsync = _serialSearchQuery.isEmpty
        ? ref.watch(soldItemsUnderWarrantyProvider)
        : ref.watch(searchSerialsForWarrantyProvider(_serialSearchQuery));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600),
      title: const Text('Create Warranty Claim'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Serial Number Search
            InfoLabel(
              label: 'Serial Number *',
              child: serialsAsync.when(
                data: (serials) => AutoSuggestBox<SerialNumberWithProduct>(
                  placeholder: 'Search serial number...',
                  items: serials
                      .map((s) => AutoSuggestBoxItem<SerialNumberWithProduct>(
                            value: s,
                            label: s.serialNumberString,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.serialNumberString,
                                    style:
                                        const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  s.productName,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[100]),
                                ),
                                if (s.warrantyEndDate != null)
                                  Text(
                                    'Warranty until: ${Formatters.date(s.warrantyEndDate!)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: s.isUnderWarranty
                                            ? Colors.green
                                            : Colors.red),
                                  ),
                              ],
                            ),
                          ))
                      .toList(),
                  onSelected: (item) {
                    if (item.value != null) {
                      final serial = item.value!;
                      ref
                          .read(warrantyClaimFormProvider.notifier)
                          .setSerialNumber(
                            serial.serialNumber.id,
                            serial.serialNumberString,
                            serial.productName,
                          );
                    }
                  },
                  onChanged: (text, reason) {
                    setState(() => _serialSearchQuery = text);
                  },
                ),
                loading: () => const ProgressRing(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            if (formState.serialNumber != null) ...[
              const SizedBox(height: 8),
              Card(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(FluentIcons.check_mark, color: Colors.green),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Serial: ${formState.serialNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Product: ${formState.productName}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[100]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Supplier
            InfoLabel(
              label: 'Supplier *',
              child: suppliersAsync.when(
                data: (suppliers) => ComboBox<String>(
                  placeholder: const Text('Select supplier'),
                  value: formState.supplierId,
                  items: suppliers
                      .map((s) => ComboBoxItem(
                            value: s.id,
                            child: Text(s.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final supplier =
                          suppliers.firstWhere((s) => s.id == value);
                      ref
                          .read(warrantyClaimFormProvider.notifier)
                          .setSupplier(value, supplier.name);
                    }
                  },
                  isExpanded: true,
                ),
                loading: () => const ProgressRing(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(height: 16),

            // Claim Reason
            InfoLabel(
              label: 'Claim Reason *',
              child: TextBox(
                controller: _reasonController,
                placeholder: 'Describe the issue...',
                maxLines: 3,
                onChanged: (value) {
                  ref
                      .read(warrantyClaimFormProvider.notifier)
                      .setClaimReason(value);
                },
              ),
            ),

            if (formState.error != null) ...[
              const SizedBox(height: 16),
              InfoBar(
                title: const Text('Error'),
                content: Text(formState.error!),
                severity: InfoBarSeverity.error,
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: formState.isSaving
              ? null
              : () async {
                  final claim = await ref
                      .read(warrantyClaimFormProvider.notifier)
                      .saveWarrantyClaim();
                  if (claim != null && mounted) {
                    Navigator.of(context).pop();
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Success'),
                        content:
                            Text('Warranty claim ${claim.claimNumber} created'),
                        severity: InfoBarSeverity.success,
                        onClose: close,
                      );
                    });
                  }
                },
          child: formState.isSaving
              ? const SizedBox(
                  width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : const Text('Create Claim'),
        ),
      ],
    );
  }
}

// Claim Detail Dialog
class _ClaimDetailDialog extends ConsumerStatefulWidget {
  final WarrantyClaimWithDetails claim;

  const _ClaimDetailDialog({required this.claim});

  @override
  ConsumerState<_ClaimDetailDialog> createState() => _ClaimDetailDialogState();
}

class _ClaimDetailDialogState extends ConsumerState<_ClaimDetailDialog> {
  @override
  Widget build(BuildContext context) {
    final historyAsync =
        ref.watch(warrantyClaimHistoryProvider(widget.claim.claim.id));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700),
      title: Row(
        children: [
          Expanded(child: Text('Claim ${widget.claim.claimNumber}')),
          _StatusBadge(status: widget.claim.status),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                        label: 'Serial Number',
                        value: widget.claim.serialNumberString),
                    _InfoRow(
                        label: 'Product', value: widget.claim.productName),
                    _InfoRow(
                        label: 'Supplier', value: widget.claim.supplierName),
                    _InfoRow(
                        label: 'Claim Reason',
                        value: widget.claim.claimReason),
                    _InfoRow(
                        label: 'Created',
                        value: Formatters.dateTime(widget.claim.createdAt)),
                    if (widget.claim.dateSentToSupplier != null)
                      _InfoRow(
                          label: 'Sent to Supplier',
                          value: Formatters.date(
                              widget.claim.dateSentToSupplier!)),
                    if (widget.claim.expectedReturnDate != null)
                      _InfoRow(
                          label: 'Expected Return',
                          value: Formatters.date(
                              widget.claim.expectedReturnDate!)),
                    if (widget.claim.actualReturnDate != null)
                      _InfoRow(
                          label: 'Actual Return',
                          value:
                              Formatters.date(widget.claim.actualReturnDate!)),
                    if (widget.claim.supplierResponse != null)
                      _InfoRow(
                          label: 'Supplier Response',
                          value: widget.claim.supplierResponse!),
                    if (widget.claim.resolutionNotes != null)
                      _InfoRow(
                          label: 'Resolution Notes',
                          value: widget.claim.resolutionNotes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status History
            Text('Status History',
                style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 8),
            historyAsync.when(
              data: (history) {
                if (history.isEmpty) {
                  return const Text('No history available');
                }
                return Card(
                  child: Column(
                    children: history
                        .map((h) => ListTile(
                              leading: Icon(
                                FluentIcons.history,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              title: Text(
                                '${h.fromStatus ?? "Created"} -> ${h.toStatus}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(Formatters.dateTime(h.changedAt)),
                                  if (h.notes != null) Text(h.notes!),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (widget.claim.status != WarrantyClaimStatus.resolved &&
            widget.claim.status != WarrantyClaimStatus.rejected)
          FilledButton(
            child: const Text('Update Status'),
            onPressed: () {
              Navigator.of(context).pop();
              _showUpdateStatusDialog(context, ref, widget.claim);
            },
          ),
      ],
    );
  }

  void _showUpdateStatusDialog(BuildContext context, WidgetRef ref,
      WarrantyClaimWithDetails claim) {
    ref.read(warrantyStatusUpdateProvider.notifier).clear();
    ref.read(warrantyStatusUpdateProvider.notifier).setClaimId(claim.claim.id);
    showDialog(
      context: context,
      builder: (context) => _UpdateStatusDialog(claim: claim),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                  color: Colors.grey[100], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Update Status Dialog
class _UpdateStatusDialog extends ConsumerStatefulWidget {
  final WarrantyClaimWithDetails claim;

  const _UpdateStatusDialog({required this.claim});

  @override
  ConsumerState<_UpdateStatusDialog> createState() =>
      _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends ConsumerState<_UpdateStatusDialog> {
  final _responseController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<WarrantyClaimStatus> _getValidTransitions() {
    final current = widget.claim.status;
    return WarrantyClaimStatus.values
        .where((s) => current.canTransitionTo(s))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(warrantyStatusUpdateProvider);
    final validTransitions = _getValidTransitions();

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500),
      title: Text('Update Status - ${widget.claim.claimNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status: ${widget.claim.statusDisplayName}',
              style: TextStyle(color: Colors.grey[100]),
            ),
            const SizedBox(height: 16),

            // New Status
            InfoLabel(
              label: 'New Status *',
              child: ComboBox<WarrantyClaimStatus>(
                placeholder: const Text('Select new status'),
                value: updateState.newStatus,
                items: validTransitions
                    .map((s) => ComboBoxItem(
                          value: s,
                          child: Text(s.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(warrantyStatusUpdateProvider.notifier)
                        .setNewStatus(value);
                  }
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 16),

            // Conditional fields based on status
            if (updateState.newStatus ==
                WarrantyClaimStatus.sentToSupplier) ...[
              InfoLabel(
                label: 'Date Sent',
                child: DatePicker(
                  selected: updateState.dateSentToSupplier ?? DateTime.now(),
                  onChanged: (date) {
                    ref
                        .read(warrantyStatusUpdateProvider.notifier)
                        .setDateSentToSupplier(date);
                  },
                ),
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Expected Return Date',
                child: DatePicker(
                  selected: updateState.expectedReturnDate ??
                      DateTime.now().add(const Duration(days: 14)),
                  onChanged: (date) {
                    ref
                        .read(warrantyStatusUpdateProvider.notifier)
                        .setExpectedReturnDate(date);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (updateState.newStatus == WarrantyClaimStatus.returned) ...[
              InfoLabel(
                label: 'Actual Return Date',
                child: DatePicker(
                  selected: updateState.actualReturnDate ?? DateTime.now(),
                  onChanged: (date) {
                    ref
                        .read(warrantyStatusUpdateProvider.notifier)
                        .setActualReturnDate(date);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Supplier Response
            InfoLabel(
              label: 'Supplier Response',
              child: TextBox(
                controller: _responseController,
                placeholder: 'Response from supplier...',
                maxLines: 2,
                onChanged: (value) {
                  ref
                      .read(warrantyStatusUpdateProvider.notifier)
                      .setSupplierResponse(value.isEmpty ? null : value);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Resolution Notes
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                placeholder: 'Additional notes...',
                maxLines: 2,
                onChanged: (value) {
                  ref
                      .read(warrantyStatusUpdateProvider.notifier)
                      .setResolutionNotes(value.isEmpty ? null : value);
                },
              ),
            ),

            if (updateState.error != null) ...[
              const SizedBox(height: 16),
              InfoBar(
                title: const Text('Error'),
                content: Text(updateState.error!),
                severity: InfoBarSeverity.error,
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: updateState.isSaving
              ? null
              : () async {
                  final success = await ref
                      .read(warrantyStatusUpdateProvider.notifier)
                      .updateStatus();
                  if (success && mounted) {
                    Navigator.of(context).pop();
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Success'),
                        content: const Text('Status updated successfully'),
                        severity: InfoBarSeverity.success,
                        onClose: close,
                      );
                    });
                  }
                },
          child: updateState.isSaving
              ? const SizedBox(
                  width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : const Text('Update'),
        ),
      ],
    );
  }
}
