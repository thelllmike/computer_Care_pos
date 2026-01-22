import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/grn_dao.dart';
import '../../providers/inventory/supplier_provider.dart';
import '../../providers/inventory/product_provider.dart';
import '../../providers/purchasing/grn_provider.dart';
import '../../providers/purchasing/purchase_order_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

class GrnScreen extends ConsumerWidget {
  const GrnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final grnsAsync = ref.watch(grnsProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Goods Received Notes (GRN)'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New GRN'),
              onPressed: () => _showCreateGrnDialog(context, ref),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    placeholder: 'Search by GRN number or supplier...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 16),
                    ),
                    onChanged: (value) {
                      ref.read(_searchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // GRN list
            Expanded(
              child: grnsAsync.when(
                data: (grns) {
                  var filtered = grns;

                  if (searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    filtered = filtered.where((g) =>
                        g.grnNumber.toLowerCase().contains(query) ||
                        (g.supplierName?.toLowerCase().contains(query) ?? false)).toList();
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }

                  return _buildGrnList(context, ref, filtered);
                },
                loading: () => const Center(child: ProgressRing()),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.document_set, size: 48, color: Colors.grey[100]),
            const SizedBox(height: 16),
            Text('No GRN records found', style: TextStyle(color: Colors.grey[100])),
            const SizedBox(height: 8),
            FilledButton(
              child: const Text('Create First GRN'),
              onPressed: () => _showCreateGrnDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrnList(BuildContext context, WidgetRef ref, List<GrnWithSupplier> grns) {
    return Card(
      child: ListView.builder(
        itemCount: grns.length,
        itemBuilder: (context, index) {
          final grn = grns[index];

          return ListTile.selectable(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                FluentIcons.download,
                color: AppTheme.successColor,
              ),
            ),
            title: Text(grn.grnNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${grn.supplierName ?? "Unknown"} | ${Formatters.date(grn.receivedDate)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatters.currency(grn.totalAmount),
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(FluentIcons.view),
                  onPressed: () => _showGrnDetailDialog(context, ref, grn.grn.id),
                ),
              ],
            ),
            onPressed: () => _showGrnDetailDialog(context, ref, grn.grn.id),
          );
        },
      ),
    );
  }

  void _showCreateGrnDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateGrnDialog(),
    );
  }

  void _showGrnDetailDialog(BuildContext context, WidgetRef ref, String grnId) {
    showDialog(
      context: context,
      builder: (context) => GrnDetailDialog(grnId: grnId),
    );
  }
}

// Create GRN Dialog
class CreateGrnDialog extends ConsumerStatefulWidget {
  const CreateGrnDialog({super.key});

  @override
  ConsumerState<CreateGrnDialog> createState() => _CreateGrnDialogState();
}

class _CreateGrnDialogState extends ConsumerState<CreateGrnDialog> {
  String? _selectedSupplierId;
  String? _selectedPOId;
  final _invoiceNumberController = TextEditingController();
  DateTime? _invoiceDate;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final formState = ref.watch(grnFormProvider);

    // Get pending POs for selected supplier
    final pendingPOsAsync = _selectedSupplierId != null
        ? ref.watch(pendingOrdersBySupplierProvider(_selectedSupplierId!))
        : null;

    ref.listen<GrnFormState>(grnFormProvider, (previous, next) {
      if (next.isSuccess && next.createdGrn != null) {
        Navigator.of(context).pop();
        ref.read(grnFormProvider.notifier).reset();
        // Open detail dialog for the new GRN
        showDialog(
          context: context,
          builder: (context) => GrnDetailDialog(grnId: next.createdGrn!.id),
        );
      }
      if (next.error != null) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(next.error!),
            severity: InfoBarSeverity.error,
          );
        });
      }
    });

    return ContentDialog(
      title: const Text('Create GRN'),
      constraints: const BoxConstraints(maxWidth: 450),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Supplier *',
              child: suppliersAsync.when(
                data: (suppliers) => ComboBox<String>(
                  placeholder: const Text('Select supplier'),
                  value: _selectedSupplierId,
                  items: suppliers.map((s) => ComboBoxItem<String>(
                        value: s.id,
                        child: Text(s.name),
                      )).toList(),
                  onChanged: (value) => setState(() {
                    _selectedSupplierId = value;
                    _selectedPOId = null;
                  }),
                  isExpanded: true,
                ),
                loading: () => const ProgressRing(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedSupplierId != null && pendingPOsAsync != null) ...[
              InfoLabel(
                label: 'Link to Purchase Order (Optional)',
                child: pendingPOsAsync.when(
                  data: (pos) => ComboBox<String>(
                    placeholder: const Text('Select PO (optional)'),
                    value: _selectedPOId,
                    items: [
                      const ComboBoxItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...pos.map((po) => ComboBoxItem<String>(
                            value: po.id,
                            child: Text('${po.orderNumber} - ${Formatters.currency(po.totalAmount)}'),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedPOId = value),
                    isExpanded: true,
                  ),
                  loading: () => const ProgressRing(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Supplier Invoice No',
                    child: TextBox(
                      controller: _invoiceNumberController,
                      placeholder: 'Enter invoice number',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Invoice Date',
                    child: DatePicker(
                      selected: _invoiceDate,
                      onChanged: (date) => setState(() => _invoiceDate = date),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Notes',
              child: TextBox(
                controller: _notesController,
                placeholder: 'Enter notes',
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: formState.isLoading || _selectedSupplierId == null
              ? null
              : () {
                  ref.read(grnFormProvider.notifier).createGrn(
                        supplierId: _selectedSupplierId!,
                        purchaseOrderId: _selectedPOId,
                        invoiceNumber: _invoiceNumberController.text.trim().isEmpty
                            ? null
                            : _invoiceNumberController.text.trim(),
                        invoiceDate: _invoiceDate,
                        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                      );
                },
          child: formState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// GRN Detail Dialog
class GrnDetailDialog extends ConsumerWidget {
  final String grnId;

  const GrnDetailDialog({super.key, required this.grnId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grnDetailAsync = ref.watch(grnDetailProvider(grnId));

    return ContentDialog(
      title: const Text('GRN Details'),
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
      content: grnDetailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('GRN not found'));
          }
          return _GrnDetailContent(detail: detail, grnId: grnId);
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _GrnDetailContent extends ConsumerWidget {
  final GrnDetail detail;
  final String grnId;

  const _GrnDetailContent({required this.detail, required this.grnId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.grnNumber,
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 4),
                  Text('Supplier: ${detail.supplierName ?? "N/A"}'),
                  Text('Date: ${Formatters.date(detail.grn.receivedDate)}'),
                  if (detail.grn.invoiceNumber != null)
                    Text('Supplier Invoice: ${detail.grn.invoiceNumber}'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(detail.totalAmount),
                    style: FluentTheme.of(context).typography.title,
                  ),
                  Text('${detail.totalQuantity} items'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Add Item Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Received Items', style: FluentTheme.of(context).typography.bodyStrong),
              FilledButton(
                child: const Text('Add Item'),
                onPressed: () => _showAddItemDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (detail.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No items received yet. Add items to this GRN.')),
            )
          else
            ...detail.items.map((item) => _buildItemCard(context, item)),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ${Formatters.currency(detail.totalAmount)}',
                style: FluentTheme.of(context).typography.subtitle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, GrnItemWithProduct item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Code: ${item.productCode}'),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Qty: ${item.quantity}'),
                    Text('Unit: ${Formatters.currency(item.unitCost)}'),
                    Text('Total: ${Formatters.currency(item.totalCost)}',
                         style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            if (item.hasSerialized && item.serials.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text('Serial Numbers:', style: FluentTheme.of(context).typography.caption),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: item.serialNumberList.map((serial) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        serial,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AddGrnItemDialog(grnId: grnId),
    );
  }
}

// Add GRN Item Dialog
class AddGrnItemDialog extends ConsumerStatefulWidget {
  final String grnId;

  const AddGrnItemDialog({super.key, required this.grnId});

  @override
  ConsumerState<AddGrnItemDialog> createState() => _AddGrnItemDialogState();
}

class _AddGrnItemDialogState extends ConsumerState<AddGrnItemDialog> {
  String? _selectedProductId;
  bool _isSerialized = false;
  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();
  final _serialsController = TextEditingController();
  List<String> _serialNumbers = [];

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _serialsController.dispose();
    super.dispose();
  }

  void _parseSerials() {
    final text = _serialsController.text.trim();
    if (text.isEmpty) {
      setState(() => _serialNumbers = []);
      return;
    }

    // Parse serials: support comma, newline, or space separated
    final serials = text
        .split(RegExp(r'[,\n\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _serialNumbers = serials;
      _quantityController.text = serials.length.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final formState = ref.watch(grnFormProvider);

    ref.listen<GrnFormState>(grnFormProvider, (previous, next) {
      if (next.isSuccess) {
        Navigator.of(context).pop();
        ref.invalidate(grnDetailProvider(widget.grnId));
      }
      if (next.error != null) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(next.error!),
            severity: InfoBarSeverity.error,
          );
        });
      }
    });

    return ContentDialog(
      title: const Text('Add Item to GRN'),
      constraints: const BoxConstraints(maxWidth: 500),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Product *',
              child: productsAsync.when(
                data: (products) => ComboBox<String>(
                  placeholder: const Text('Select product'),
                  value: _selectedProductId,
                  items: products.map((p) => ComboBoxItem<String>(
                        value: p.id,
                        child: Text('${p.name} (${p.code})'),
                      )).toList(),
                  onChanged: (value) {
                    final product = products.firstWhere((p) => p.id == value);
                    setState(() {
                      _selectedProductId = value;
                      _isSerialized = product.requiresSerial;
                    });
                    _unitCostController.text = product.weightedAvgCost.toString();
                  },
                  isExpanded: true,
                ),
                loading: () => const ProgressRing(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(height: 16),

            if (_isSerialized) ...[
              InfoBar(
                title: const Text('Serialized Product'),
                content: const Text('Enter serial numbers below. Quantity will be calculated automatically.'),
                severity: InfoBarSeverity.info,
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Serial Numbers * (one per line or comma separated)',
                child: TextBox(
                  controller: _serialsController,
                  placeholder: 'SN001\nSN002\nSN003',
                  maxLines: 6,
                  onChanged: (_) => _parseSerials(),
                ),
              ),
              const SizedBox(height: 8),
              if (_serialNumbers.isNotEmpty)
                Text('${_serialNumbers.length} serial number(s) detected',
                    style: TextStyle(color: AppTheme.successColor)),
              if (formState.duplicateSerials.isNotEmpty) ...[
                const SizedBox(height: 8),
                InfoBar(
                  title: const Text('Duplicate Serials Found'),
                  content: Text(formState.duplicateSerials.join(', ')),
                  severity: InfoBarSeverity.error,
                ),
              ],
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Quantity',
                    child: TextBox(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      enabled: !_isSerialized,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoLabel(
                    label: 'Unit Cost *',
                    child: TextBox(
                      controller: _unitCostController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: formState.isLoading || _selectedProductId == null
              ? null
              : () => _submit(),
          child: formState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  void _submit() {
    final unitCost = double.tryParse(_unitCostController.text) ?? 0;

    if (unitCost <= 0) {
      displayInfoBar(context, builder: (context, close) {
        return const InfoBar(
          title: Text('Validation Error'),
          content: Text('Unit cost must be greater than 0'),
          severity: InfoBarSeverity.warning,
        );
      });
      return;
    }

    if (_isSerialized) {
      if (_serialNumbers.isEmpty) {
        displayInfoBar(context, builder: (context, close) {
          return const InfoBar(
            title: Text('Validation Error'),
            content: Text('Please enter at least one serial number'),
            severity: InfoBarSeverity.warning,
          );
        });
        return;
      }

      ref.read(grnFormProvider.notifier).addSerializedItem(
            grnId: widget.grnId,
            productId: _selectedProductId!,
            serialNumbers: _serialNumbers,
            unitCost: unitCost,
          );
    } else {
      final quantity = int.tryParse(_quantityController.text) ?? 0;
      if (quantity <= 0) {
        displayInfoBar(context, builder: (context, close) {
          return const InfoBar(
            title: Text('Validation Error'),
            content: Text('Quantity must be greater than 0'),
            severity: InfoBarSeverity.warning,
          );
        });
        return;
      }

      ref.read(grnFormProvider.notifier).addItem(
            grnId: widget.grnId,
            productId: _selectedProductId!,
            quantity: quantity,
            unitCost: unitCost,
          );
    }
  }
}
