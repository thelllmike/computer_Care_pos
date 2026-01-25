import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/repair_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../providers/repairs/repair_provider.dart';
import '../../providers/inventory/customer_provider.dart';
import '../../providers/inventory/product_provider.dart';
import '../../providers/core/database_provider.dart';
import '../../providers/core/settings_provider.dart';

class RepairsScreen extends ConsumerWidget {
  const RepairsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(repairSummaryProvider);
    final searchQuery = ref.watch(repairSearchQueryProvider);
    final statusFilter = ref.watch(repairStatusFilterProvider);

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Repair Jobs'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Job Card'),
              onPressed: () => _showCreateJobDialog(context, ref),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(repairJobsProvider);
                ref.invalidate(repairSummaryProvider);
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
                        title: 'Active Jobs',
                        value: summary.activeJobs.toString(),
                        icon: FluentIcons.repair,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pending Diagnosis',
                        value: summary.pendingJobs.toString(),
                        icon: FluentIcons.search,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Completed Today',
                        value: summary.completedToday.toString(),
                        icon: FluentIcons.completed_solid,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Revenue',
                        value: Formatters.currency(summary.totalRevenue),
                        icon: FluentIcons.money,
                        color: Colors.teal,
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
                error: (e, _) => InfoBar(
                  title: const Text('Error'),
                  content: Text(e.toString()),
                  severity: InfoBarSeverity.error,
                ),
              ),
              const SizedBox(height: 24),

              // Search and filter
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      placeholder: 'Search by job number or customer...',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(FluentIcons.search, size: 16),
                      ),
                      onChanged: (value) =>
                          ref.read(repairSearchQueryProvider.notifier).state = value,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ComboBox<RepairStatus?>(
                    value: statusFilter,
                    placeholder: const Text('All Status'),
                    items: [
                      const ComboBoxItem<RepairStatus?>(
                        value: null,
                        child: Text('All Status'),
                      ),
                      ...RepairStatus.values.map((s) => ComboBoxItem(
                            value: s,
                            child: Text(s.displayName),
                          )),
                    ],
                    onChanged: (value) =>
                        ref.read(repairStatusFilterProvider.notifier).state = value,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Job list
              _RepairJobsList(searchQuery: searchQuery, statusFilter: statusFilter),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateJobDialog(BuildContext context, WidgetRef ref) {
    ref.read(repairFormProvider.notifier).clear();
    showDialog(
      context: context,
      builder: (context) => const _RepairJobFormDialog(),
    );
  }
}

// ==================== Summary Card ====================

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
            Column(
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

// ==================== Repair Jobs List ====================

class _RepairJobsList extends ConsumerWidget {
  final String searchQuery;
  final RepairStatus? statusFilter;

  const _RepairJobsList({
    required this.searchQuery,
    required this.statusFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = statusFilter != null
        ? ref.watch(repairJobsByStatusProvider(statusFilter))
        : ref.watch(repairJobsProvider);

    return jobsAsync.when(
      data: (jobs) {
        var filtered = jobs;

        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          filtered = filtered
              .where((j) =>
                  j.jobNumber.toLowerCase().contains(query) ||
                  (j.customerName?.toLowerCase().contains(query) ?? false))
              .toList();
        }

        if (filtered.isEmpty) {
          return Card(
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
          );
        }

        return Card(
          child: Column(
            children: filtered
                .map((job) => _RepairJobTile(
                      job: job,
                      onTap: () => _showJobDetailDialog(context, ref, job.repairJob.id),
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
    );
  }

  void _showJobDetailDialog(BuildContext context, WidgetRef ref, String jobId) {
    showDialog(
      context: context,
      builder: (context) => _RepairJobDetailDialog(jobId: jobId),
    );
  }
}

// ==================== Repair Job Tile ====================

class _RepairJobTile extends StatelessWidget {
  final RepairJobWithCustomer job;
  final VoidCallback onTap;

  const _RepairJobTile({
    required this.job,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getStatusColor(job.statusEnum).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          FluentIcons.repair,
          color: _getStatusColor(job.statusEnum),
        ),
      ),
      title: Row(
        children: [
          Text(job.jobNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(job.statusEnum).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              job.statusEnum.displayName,
              style: TextStyle(
                fontSize: 10,
                color: _getStatusColor(job.statusEnum),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${job.customerName ?? "Unknown"} | ${job.deviceType}'),
          Text(
            'Received: ${Formatters.date(job.receivedDate)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[100]),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Formatters.currency(job.totalCost),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (job.repairJob.isUnderWarranty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'WARRANTY',
                style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onPressed: onTap,
    );
  }

  Color _getStatusColor(RepairStatus status) {
    switch (status) {
      case RepairStatus.received:
        return Colors.blue;
      case RepairStatus.diagnosing:
        return AppTheme.warningColor;
      case RepairStatus.waitingApproval:
        return Colors.orange;
      case RepairStatus.waitingParts:
        return Colors.purple;
      case RepairStatus.inProgress:
        return AppTheme.primaryColor;
      case RepairStatus.completed:
        return AppTheme.successColor;
      case RepairStatus.readyForPickup:
        return Colors.teal;
      case RepairStatus.delivered:
        return Colors.grey;
      case RepairStatus.cancelled:
        return AppTheme.errorColor;
    }
  }
}

// ==================== Repair Job Form Dialog ====================

class _RepairJobFormDialog extends ConsumerStatefulWidget {
  const _RepairJobFormDialog();

  @override
  ConsumerState<_RepairJobFormDialog> createState() => _RepairJobFormDialogState();
}

class _RepairJobFormDialogState extends ConsumerState<_RepairJobFormDialog> {
  final _problemController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _problemController.dispose();
    _estimatedCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(repairFormProvider);
    final customersAsync = ref.watch(customersProvider);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600),
      title: Text(formState.isEditing ? 'Edit Repair Job' : 'New Repair Job'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer type toggle
            Row(
              children: [
                Expanded(
                  child: RadioButton(
                    checked: !formState.useManualCustomer,
                    content: const Text('Existing Customer'),
                    onChanged: (checked) {
                      if (checked) {
                        ref.read(repairFormProvider.notifier).setUseManualCustomer(false);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioButton(
                    checked: formState.useManualCustomer,
                    content: const Text('Walk-in Customer'),
                    onChanged: (checked) {
                      if (checked) {
                        ref.read(repairFormProvider.notifier).setUseManualCustomer(true);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer selection or manual entry
            if (!formState.useManualCustomer) ...[
              InfoLabel(
                label: 'Customer *',
                child: customersAsync.when(
                  data: (customers) => AutoSuggestBox<String>(
                    placeholder: 'Search customer...',
                    items: customers
                        .map((c) => AutoSuggestBoxItem(
                              value: c.id,
                              label: '${c.name} - ${c.phone ?? "No phone"}',
                            ))
                        .toList(),
                    onSelected: (item) {
                      final customer = customers.firstWhere((c) => c.id == item.value);
                      ref.read(repairFormProvider.notifier).setCustomer(
                            customer.id,
                            customer.name,
                          );
                    },
                  ),
                  loading: () => const ProgressRing(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
              if (formState.customerName != null) ...[
                const SizedBox(height: 8),
                Text('Selected: ${formState.customerName}',
                    style: TextStyle(color: AppTheme.primaryColor)),
              ],
            ] else ...[
              // Manual customer entry
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: InfoLabel(
                      label: 'Customer Name *',
                      child: TextBox(
                        placeholder: 'Enter customer name',
                        onChanged: (value) {
                          ref.read(repairFormProvider.notifier).setManualCustomer(
                                value.isEmpty ? null : value,
                                formState.manualCustomerPhone,
                              );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InfoLabel(
                      label: 'Phone',
                      child: TextBox(
                        placeholder: 'Phone number',
                        onChanged: (value) {
                          ref.read(repairFormProvider.notifier).setManualCustomer(
                                formState.manualCustomerName,
                                value.isEmpty ? null : value,
                              );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Device type
            InfoLabel(
              label: 'Device Type *',
              child: ComboBox<String>(
                value: formState.deviceType,
                items: const [
                  ComboBoxItem(value: 'LAPTOP', child: Text('Laptop')),
                  ComboBoxItem(value: 'DESKTOP', child: Text('Desktop')),
                  ComboBoxItem(value: 'PHONE', child: Text('Phone')),
                  ComboBoxItem(value: 'TABLET', child: Text('Tablet')),
                  ComboBoxItem(value: 'PRINTER', child: Text('Printer')),
                  ComboBoxItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(repairFormProvider.notifier).setDeviceType(value);
                  }
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 16),

            // Device info
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Brand',
                    child: TextBox(
                      placeholder: 'e.g., Dell, HP, Apple',
                      onChanged: (value) {
                        ref.read(repairFormProvider.notifier).setDeviceInfo(
                              brand: value.isEmpty ? null : value,
                            );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Model',
                    child: TextBox(
                      placeholder: 'e.g., Inspiron 15',
                      onChanged: (value) {
                        ref.read(repairFormProvider.notifier).setDeviceInfo(
                              model: value.isEmpty ? null : value,
                            );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Serial number
            InfoLabel(
              label: 'Serial Number',
              child: TextBox(
                placeholder: 'Device serial number (optional)',
                onChanged: (value) {
                  ref.read(repairFormProvider.notifier).setDeviceInfo(
                        serial: value.isEmpty ? null : value,
                      );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Warranty info if our device
            if (formState.warrantyInfo != null) ...[
              Card(
                backgroundColor: formState.isUnderWarranty
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        formState.isUnderWarranty
                            ? FluentIcons.completed_solid
                            : FluentIcons.warning,
                        color: formState.isUnderWarranty
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formState.isUnderWarranty
                                  ? 'Under Warranty'
                                  : 'Out of Warranty',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              formState.warrantyInfo!.productName,
                              style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                            ),
                            if (formState.warrantyInfo!.warrantyExpiry != null)
                              Text(
                                'Expires: ${Formatters.date(formState.warrantyInfo!.warrantyExpiry!)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Problem description
            InfoLabel(
              label: 'Problem Description *',
              child: TextBox(
                controller: _problemController,
                maxLines: 3,
                placeholder: 'Describe the issue...',
                onChanged: (value) {
                  ref.read(repairFormProvider.notifier).setProblemDescription(value);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Estimated cost
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Estimated Cost',
                    child: TextBox(
                      controller: _estimatedCostController,
                      keyboardType: TextInputType.number,
                      placeholder: '0.00',
                      onChanged: (value) {
                        final cost = double.tryParse(value) ?? 0;
                        ref.read(repairFormProvider.notifier).setEstimatedCost(cost);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Promised Date',
                    child: DatePicker(
                      selected: formState.promisedDate,
                      onChanged: (date) {
                        ref.read(repairFormProvider.notifier).setPromisedDate(date);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                maxLines: 2,
                placeholder: 'Additional notes (optional)',
                onChanged: (value) {
                  ref.read(repairFormProvider.notifier).setNotes(
                        value.isEmpty ? null : value,
                      );
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
          onPressed: formState.isSaving ? null : () => _saveJob(context),
          child: formState.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Create Job'),
        ),
      ],
    );
  }

  void _saveJob(BuildContext context) async {
    final job = await ref.read(repairFormProvider.notifier).saveRepairJob();
    if (job != null && context.mounted) {
      Navigator.of(context).pop();
      displayInfoBar(context, builder: (context, close) {
        return InfoBar(
          title: const Text('Success'),
          content: Text('Job ${job.jobNumber} created'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      });
    }
  }
}

// ==================== Repair Job Detail Dialog ====================

class _RepairJobDetailDialog extends ConsumerWidget {
  final String jobId;

  const _RepairJobDetailDialog({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(repairJobDetailProvider(jobId));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
      title: const Text('Repair Job Details'),
      content: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Job not found'));
          }
          return _RepairJobDetailContent(detail: detail);
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (detailAsync.valueOrNull != null &&
            (detailAsync.valueOrNull!.repairJob.status == 'COMPLETED' ||
             detailAsync.valueOrNull!.repairJob.status == 'READY_FOR_PICKUP' ||
             detailAsync.valueOrNull!.repairJob.status == 'DELIVERED'))
          Button(
            child: const Text('Generate Invoice'),
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => _GenerateInvoiceDialog(
                  jobId: jobId,
                  jobNumber: detailAsync.valueOrNull!.repairJob.jobNumber,
                  totalCost: detailAsync.valueOrNull!.repairJob.totalCost,
                ),
              );
            },
          ),
        if (detailAsync.valueOrNull != null &&
            detailAsync.valueOrNull!.repairJob.status != 'DELIVERED' &&
            detailAsync.valueOrNull!.repairJob.status != 'CANCELLED')
          FilledButton(
            child: const Text('Update Status'),
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => _UpdateStatusDialog(
                  jobId: jobId,
                  currentStatus: RepairStatusExtension.fromString(
                      detailAsync.valueOrNull!.repairJob.status),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _RepairJobDetailContent extends ConsumerWidget {
  final RepairJobDetail detail;

  const _RepairJobDetailContent({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = detail.repairJob;
    final status = RepairStatusExtension.fromString(job.status);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.jobNumber,
                        style: FluentTheme.of(context).typography.subtitle),
                    const SizedBox(height: 4),
                    Text('Customer: ${detail.customer?.name ?? "Unknown"}'),
                    Text('Phone: ${detail.customer?.phone ?? "N/A"}'),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  if (job.isUnderWarranty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'WARRANTY',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Device info
          Text('Device Information',
              style: FluentTheme.of(context).typography.bodyStrong),
          const SizedBox(height: 8),
          _InfoRow('Type', job.deviceType),
          if (job.deviceBrand != null) _InfoRow('Brand', job.deviceBrand!),
          if (job.deviceModel != null) _InfoRow('Model', job.deviceModel!),
          if (job.deviceSerial != null) _InfoRow('Serial', job.deviceSerial!),
          const SizedBox(height: 16),

          // Problem & Diagnosis
          Text('Problem Description',
              style: FluentTheme.of(context).typography.bodyStrong),
          const SizedBox(height: 8),
          Card(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(job.problemDescription),
            ),
          ),
          if (job.diagnosis != null) ...[
            const SizedBox(height: 16),
            Text('Diagnosis', style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 8),
            Card(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(job.diagnosis!),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Costs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Costs', style: FluentTheme.of(context).typography.bodyStrong),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.edit, size: 14),
                    SizedBox(width: 4),
                    Text('Edit Costs'),
                  ],
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _EditCostsDialog(
                      repairJobId: detail.repairJob.id,
                      currentEstimatedCost: job.estimatedCost,
                      currentLaborCost: job.laborCost,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _CostRow('Estimated', job.estimatedCost),
                  _CostRow('Labor', job.laborCost),
                  _CostRow('Parts', job.partsCost),
                  const Divider(),
                  _CostRow('Total', job.totalCost, isTotal: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Parts used
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Parts Used', style: FluentTheme.of(context).typography.bodyStrong),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 14),
                    SizedBox(width: 4),
                    Text('Add Part'),
                  ],
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _AddPartDialog(
                      repairJobId: detail.repairJob.id,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (detail.parts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(FluentIcons.package, size: 32, color: Colors.grey[100]),
                      const SizedBox(height: 8),
                      Text('No parts added yet', style: TextStyle(color: Colors.grey[100])),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: detail.parts
                    .map((part) => ListTile(
                          title: Text(part.productName),
                          subtitle: Text('Qty: ${part.part.quantity} × ${Formatters.currency(part.part.unitPrice)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Formatters.currency(part.part.totalPrice),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(FluentIcons.delete, size: 16, color: AppTheme.errorColor),
                                onPressed: () => _showRemovePartDialog(context, ref, part.part.id, detail.repairJob.id),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),

          // Dates
          Text('Timeline', style: FluentTheme.of(context).typography.bodyStrong),
          const SizedBox(height: 8),
          _InfoRow('Received', Formatters.dateTime(job.receivedDate)),
          if (job.promisedDate != null)
            _InfoRow('Promised', Formatters.date(job.promisedDate!)),
          if (job.completedDate != null)
            _InfoRow('Completed', Formatters.dateTime(job.completedDate!)),
          if (job.deliveredDate != null)
            _InfoRow('Delivered', Formatters.dateTime(job.deliveredDate!)),
        ],
      ),
    );
  }

  Color _getStatusColor(RepairStatus status) {
    switch (status) {
      case RepairStatus.received:
        return Colors.blue;
      case RepairStatus.diagnosing:
        return AppTheme.warningColor;
      case RepairStatus.waitingApproval:
        return Colors.orange;
      case RepairStatus.waitingParts:
        return Colors.purple;
      case RepairStatus.inProgress:
        return AppTheme.primaryColor;
      case RepairStatus.completed:
        return AppTheme.successColor;
      case RepairStatus.readyForPickup:
        return Colors.teal;
      case RepairStatus.delivered:
        return Colors.grey;
      case RepairStatus.cancelled:
        return AppTheme.errorColor;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[100])),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;

  const _CostRow(this.label, this.amount, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : null,
            ),
          ),
          Text(
            Formatters.currency(amount),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : null,
              color: isTotal ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Update Status Dialog ====================

class _UpdateStatusDialog extends ConsumerStatefulWidget {
  final String jobId;
  final RepairStatus currentStatus;

  const _UpdateStatusDialog({
    required this.jobId,
    required this.currentStatus,
  });

  @override
  ConsumerState<_UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends ConsumerState<_UpdateStatusDialog> {
  RepairStatus? _selectedStatus;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<RepairStatus> _getValidTransitions() {
    return RepairStatus.values
        .where((s) => widget.currentStatus.canTransitionTo(s))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(statusUpdateProvider);
    final validTransitions = _getValidTransitions();

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 400),
      title: const Text('Update Status'),
      content: updateState.isSuccess
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.completed_solid,
                    size: 48, color: AppTheme.successColor),
                const SizedBox(height: 16),
                const Text('Status updated successfully'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Status: ${widget.currentStatus.displayName}'),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'New Status',
                  child: ComboBox<RepairStatus>(
                    value: _selectedStatus,
                    placeholder: const Text('Select new status'),
                    items: validTransitions
                        .map((s) => ComboBoxItem(
                              value: s,
                              child: Text(s.displayName),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedStatus = value),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Notes (optional)',
                  child: TextBox(
                    controller: _notesController,
                    maxLines: 2,
                    placeholder: 'Reason for status change',
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
      actions: updateState.isSuccess
          ? [
              FilledButton(
                child: const Text('Done'),
                onPressed: () {
                  ref.read(statusUpdateProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
              ),
            ]
          : [
              Button(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              FilledButton(
                onPressed: _selectedStatus == null || updateState.isProcessing
                    ? null
                    : _updateStatus,
                child: updateState.isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Text('Update'),
              ),
            ],
    );
  }

  void _updateStatus() {
    if (_selectedStatus == null) return;

    ref.read(statusUpdateProvider.notifier).updateStatus(
          jobId: widget.jobId,
          newStatus: _selectedStatus!,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
  }
}

class _GenerateInvoiceDialog extends ConsumerStatefulWidget {
  final String jobId;
  final String jobNumber;
  final double totalCost;

  const _GenerateInvoiceDialog({
    required this.jobId,
    required this.jobNumber,
    required this.totalCost,
  });

  @override
  ConsumerState<_GenerateInvoiceDialog> createState() => _GenerateInvoiceDialogState();
}

class _GenerateInvoiceDialogState extends ConsumerState<_GenerateInvoiceDialog> {
  bool _isCredit = false;
  bool _isPartialPayment = false;
  final _discountController = TextEditingController(text: '0');
  final _partialPaymentController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    _partialPaymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(serviceInvoiceProvider);
    final discount = double.tryParse(_discountController.text) ?? 0;
    final finalAmount = widget.totalCost - discount;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 450),
      title: const Text('Generate Service Invoice'),
      content: invoiceState.isSuccess
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.check_mark,
                  size: 48,
                  color: AppTheme.successColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Invoice Generated!',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Text('Invoice Number: ${invoiceState.invoiceNumber}'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoBar(
                  title: Text('Repair Job: ${widget.jobNumber}'),
                  content: Text(
                    'Total Amount: ${Formatters.currency(widget.totalCost)}',
                  ),
                  severity: InfoBarSeverity.info,
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Discount Amount',
                  child: TextBox(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('Rs.'),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Final Amount:'),
                    Text(
                      Formatters.currency(finalAmount),
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Checkbox(
                  checked: _isCredit,
                  onChanged: (value) => setState(() {
                    _isCredit = value ?? false;
                    if (!_isCredit) {
                      _isPartialPayment = false;
                      _partialPaymentController.clear();
                    }
                  }),
                  content: const Text('Credit Sale (Customer will pay later)'),
                ),
                if (_isCredit) ...[
                  const SizedBox(height: 12),
                  Checkbox(
                    checked: _isPartialPayment,
                    onChanged: (value) => setState(() {
                      _isPartialPayment = value ?? false;
                      if (!_isPartialPayment) {
                        _partialPaymentController.clear();
                      }
                    }),
                    content: const Text('Partial Payment (Pay some now, rest as credit)'),
                  ),
                  if (_isPartialPayment) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: 'Amount Paying Now',
                      child: TextBox(
                        controller: _partialPaymentController,
                        keyboardType: TextInputType.number,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('Rs.'),
                        ),
                        placeholder: '0.00',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final partialPay = double.tryParse(_partialPaymentController.text) ?? 0;
                      final creditAmount = finalAmount - partialPay;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Credit Amount:'),
                          Text(
                            Formatters.currency(creditAmount > 0 ? creditAmount : 0),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ],
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Notes (optional)',
                  child: TextBox(
                    controller: _notesController,
                    maxLines: 2,
                    placeholder: 'Additional notes for the invoice',
                  ),
                ),
                if (invoiceState.error != null) ...[
                  const SizedBox(height: 16),
                  InfoBar(
                    title: const Text('Error'),
                    content: Text(invoiceState.error!),
                    severity: InfoBarSeverity.error,
                  ),
                ],
              ],
            ),
      actions: invoiceState.isSuccess
          ? [
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.print, size: 16),
                    SizedBox(width: 8),
                    Text('Print Invoice'),
                  ],
                ),
                onPressed: () async {
                  await _printRepairInvoice(invoiceState);
                },
              ),
              FilledButton(
                child: const Text('Done'),
                onPressed: () {
                  ref.read(serviceInvoiceProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
              ),
            ]
          : [
              Button(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              FilledButton(
                onPressed: invoiceState.isProcessing ? null : _generateInvoice,
                child: invoiceState.isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Text('Generate Invoice'),
              ),
            ],
    );
  }

  void _generateInvoice() {
    final discount = double.tryParse(_discountController.text) ?? 0;
    final partialPayment = _isPartialPayment
        ? double.tryParse(_partialPaymentController.text)
        : null;

    ref.read(serviceInvoiceProvider.notifier).generateInvoice(
          repairJobId: widget.jobId,
          isCredit: _isCredit,
          discountAmount: discount,
          partialPayment: partialPayment,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
  }

  Future<void> _printRepairInvoice(ServiceInvoiceState invoiceState) async {
    try {
      final companySettings = await ref.read(companySettingsProvider.future);
      final jobDetail = await ref.read(repairJobDetailProvider(widget.jobId).future);

      if (jobDetail == null) {
        throw Exception('Repair job not found');
      }

      final discount = double.tryParse(_discountController.text) ?? 0;
      final finalAmount = widget.totalCost - discount;

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          companySettings.name.isNotEmpty ? companySettings.name : 'M-TRONIC',
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        if (companySettings.address.isNotEmpty)
                          pw.Text(companySettings.address),
                        if (companySettings.phone.isNotEmpty)
                          pw.Text('Tel: ${companySettings.phone}'),
                        if (companySettings.email.isNotEmpty)
                          pw.Text('Email: ${companySettings.email}'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'SERVICE INVOICE',
                          style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                        ),
                        pw.Text(invoiceState.invoiceNumber ?? '', style: const pw.TextStyle(fontSize: 16)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // Customer and Job info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Customer:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(jobDetail.customer?.name ?? 'Walk-in Customer'),
                          if (jobDetail.customer?.phone != null)
                            pw.Text('Tel: ${jobDetail.customer!.phone}'),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Job #: ${jobDetail.repairJob.jobNumber}'),
                        pw.Text('Date: ${Formatters.date(DateTime.now())}'),
                        if (_isCredit)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.orange100,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text('CREDIT SALE', style: const pw.TextStyle(color: PdfColors.orange900)),
                          ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Device info
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Device Information:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('${jobDetail.repairJob.deviceBrand ?? ''} ${jobDetail.repairJob.deviceModel ?? ''} (${jobDetail.repairJob.deviceType})'),
                      if (jobDetail.repairJob.deviceSerial != null)
                        pw.Text('Serial: ${jobDetail.repairJob.deviceSerial}'),
                      pw.SizedBox(height: 8),
                      pw.Text('Problem: ${jobDetail.repairJob.problemDescription}'),
                      if (jobDetail.repairJob.diagnosis != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Diagnosis: ${jobDetail.repairJob.diagnosis}'),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Parts table
                if (jobDetail.parts.isNotEmpty) ...[
                  pw.Text('Parts Used:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Part', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      ...jobDetail.parts.map((part) => pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(part.productName)),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${part.part.quantity}')),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(Formatters.currency(part.part.unitPrice))),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(Formatters.currency(part.part.totalPrice))),
                            ],
                          )),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 220,
                      child: pw.Column(
                        children: [
                          _pdfTotalRow('Labor Cost', jobDetail.repairJob.laborCost),
                          _pdfTotalRow('Parts Cost', jobDetail.repairJob.partsCost),
                          if (discount > 0)
                            _pdfTotalRow('Discount', -discount),
                          pw.Divider(color: PdfColors.green300),
                          _pdfTotalRow('Total', finalAmount, isTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Center(child: pw.Text('Thank you for your business!')),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    AppConstants.poweredBy,
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'ServiceInvoice_${invoiceState.invoiceNumber}',
      );
    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Print Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }

  static pw.Widget _pdfTotalRow(String label, double amount, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isTotal ? pw.FontWeight.bold : null, fontSize: isTotal ? 14 : 12)),
          pw.Text(
            Formatters.currency(amount),
            style: pw.TextStyle(fontWeight: isTotal ? pw.FontWeight.bold : null, fontSize: isTotal ? 14 : 12, color: isTotal ? PdfColors.green700 : null),
          ),
        ],
      ),
    );
  }
}

// ==================== Add Part Dialog ====================

class _AddPartDialog extends ConsumerStatefulWidget {
  final String repairJobId;

  const _AddPartDialog({required this.repairJobId});

  @override
  ConsumerState<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends ConsumerState<_AddPartDialog> {
  Product? _selectedProduct;
  int _quantity = 1;
  double _unitPrice = 0;
  double _unitCost = 0;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500),
      title: const Text('Add Part to Repair'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: 'Select Part/Product *',
            child: productsAsync.when(
              data: (products) => AutoSuggestBox<String>(
                placeholder: 'Search product...',
                items: products
                    .map((p) => AutoSuggestBoxItem(
                          value: p.id,
                          label: '${p.code} - ${p.name}',
                        ))
                    .toList(),
                onSelected: (item) async {
                  final product = products.firstWhere((p) => p.id == item.value);
                  final db = ref.read(databaseProvider);
                  final inventory = await db.inventoryDao.getInventoryByProductId(product.id);

                  setState(() {
                    _selectedProduct = product;
                    _unitPrice = product.sellingPrice;
                    _unitCost = inventory?.quantityOnHand != null && inventory!.quantityOnHand > 0
                        ? inventory.totalCost / inventory.quantityOnHand
                        : product.weightedAvgCost;
                  });
                },
              ),
              loading: () => const ProgressRing(),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
          if (_selectedProduct != null) ...[
            const SizedBox(height: 8),
            Card(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Code: ${_selectedProduct!.code}'),
                          FutureBuilder(
                            future: ref.read(databaseProvider).inventoryDao.getInventoryByProductId(_selectedProduct!.id),
                            builder: (context, snapshot) {
                              final qty = snapshot.data?.quantityOnHand ?? 0;
                              return Text(
                                'In Stock: $qty',
                                style: TextStyle(
                                  color: qty > 0 ? AppTheme.successColor : AppTheme.errorColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Quantity',
                    child: NumberBox<int>(
                      value: _quantity,
                      min: 1,
                      max: 100,
                      onChanged: (value) => setState(() => _quantity = value ?? 1),
                      mode: SpinButtonPlacementMode.inline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Unit Price (Selling)',
                    child: TextBox(
                      controller: TextEditingController(text: _unitPrice.toStringAsFixed(2)),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _unitPrice = double.tryParse(value) ?? _unitPrice,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Price:'),
                    Text(
                      Formatters.currency(_unitPrice * _quantity),
                      style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            InfoBar(
              title: const Text('Error'),
              content: Text(_error!),
              severity: InfoBarSeverity.error,
            ),
          ],
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: _selectedProduct == null || _isLoading ? null : _addPart,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Add Part'),
        ),
      ],
    );
  }

  Future<void> _addPart() async {
    if (_selectedProduct == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await ref.read(partsManagementProvider.notifier).addPart(
            repairJobId: widget.repairJobId,
            productId: _selectedProduct!.id,
            quantity: _quantity,
            unitCost: _unitCost,
            unitPrice: _unitPrice,
          );

      if (success && mounted) {
        ref.invalidate(repairJobDetailProvider(widget.repairJobId));
        Navigator.of(context).pop();
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Part added successfully'),
            content: Text('${_quantity}x ${_selectedProduct!.name} added'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
      } else if (mounted) {
        setState(() {
          _error = 'Failed to add part. Check stock availability.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
}

// ==================== Edit Costs Dialog ====================

class _EditCostsDialog extends ConsumerStatefulWidget {
  final String repairJobId;
  final double currentEstimatedCost;
  final double currentLaborCost;

  const _EditCostsDialog({
    required this.repairJobId,
    required this.currentEstimatedCost,
    required this.currentLaborCost,
  });

  @override
  ConsumerState<_EditCostsDialog> createState() => _EditCostsDialogState();
}

class _EditCostsDialogState extends ConsumerState<_EditCostsDialog> {
  late TextEditingController _estimatedCostController;
  late TextEditingController _laborCostController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _estimatedCostController = TextEditingController(
      text: widget.currentEstimatedCost.toStringAsFixed(2),
    );
    _laborCostController = TextEditingController(
      text: widget.currentLaborCost.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _estimatedCostController.dispose();
    _laborCostController.dispose();
    super.dispose();
  }

  Future<void> _saveCosts() async {
    setState(() => _isLoading = true);

    try {
      final estimatedCost = double.tryParse(_estimatedCostController.text) ?? 0;
      final laborCost = double.tryParse(_laborCostController.text) ?? 0;

      final db = ref.read(databaseProvider);
      await db.repairDao.updateRepairJob(
        id: widget.repairJobId,
        estimatedCost: estimatedCost,
        laborCost: laborCost,
      );

      ref.invalidate(repairJobDetailProvider(widget.repairJobId));
      ref.invalidate(repairJobsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Costs updated successfully'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Failed to update costs'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 400),
      title: const Text('Edit Repair Costs'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoLabel(
            label: 'Estimated Cost',
            child: TextBox(
              controller: _estimatedCostController,
              keyboardType: TextInputType.number,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('LKR'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Labor Cost',
            child: TextBox(
              controller: _laborCostController,
              keyboardType: TextInputType.number,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('LKR'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InfoBar(
            title: const Text('Note'),
            content: const Text('Parts cost is calculated from added parts. Total = Labor + Parts'),
            severity: InfoBarSeverity.info,
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveCosts,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// Helper function to confirm part removal
void _showRemovePartDialog(BuildContext context, WidgetRef ref, String partId, String repairJobId) {
  showDialog(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('Remove Part'),
      content: const Text('Are you sure you want to remove this part? It will be returned to inventory.'),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        FilledButton(
          style: ButtonStyle(backgroundColor: WidgetStateProperty.all(AppTheme.errorColor)),
          child: const Text('Remove'),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            try {
              await ref.read(partsManagementProvider.notifier).removePart(partId, repairJobId);
              ref.invalidate(repairJobDetailProvider(repairJobId));
              if (context.mounted) {
                displayInfoBar(context, builder: (context, close) {
                  return InfoBar(
                    title: const Text('Part removed'),
                    content: const Text('Part returned to inventory'),
                    severity: InfoBarSeverity.success,
                    onClose: close,
                  );
                });
              }
            } catch (e) {
              if (context.mounted) {
                displayInfoBar(context, builder: (context, close) {
                  return InfoBar(
                    title: const Text('Error'),
                    content: Text(e.toString()),
                    severity: InfoBarSeverity.error,
                    onClose: close,
                  );
                });
              }
            }
          },
        ),
      ],
    ),
  );
}
