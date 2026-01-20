import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/order_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/purchase_order_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../providers/inventory/supplier_provider.dart';
import '../../providers/inventory/product_provider.dart';
import '../../providers/purchasing/purchase_order_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _statusFilterProvider = StateProvider<OrderStatus?>((ref) => null);

class PurchaseOrdersScreen extends ConsumerWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final statusFilter = ref.watch(_statusFilterProvider);
    final purchaseOrdersAsync = ref.watch(purchaseOrdersProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Purchase Orders'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Purchase Order'),
              onPressed: () => _showCreatePODialog(context, ref),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and filters
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    placeholder: 'Search by PO number or supplier...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 16),
                    ),
                    onChanged: (value) {
                      ref.read(_searchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 180,
                  child: ComboBox<OrderStatus?>(
                    placeholder: const Text('All Statuses'),
                    value: statusFilter,
                    items: [
                      const ComboBoxItem<OrderStatus?>(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      ...OrderStatus.values.map((status) => ComboBoxItem<OrderStatus?>(
                            value: status,
                            child: Text(status.displayName),
                          )),
                    ],
                    onChanged: (value) {
                      ref.read(_statusFilterProvider.notifier).state = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Purchase orders list
            Expanded(
              child: purchaseOrdersAsync.when(
                data: (purchaseOrders) {
                  var filtered = purchaseOrders;

                  if (searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    filtered = filtered.where((po) =>
                        po.poNumber.toLowerCase().contains(query) ||
                        (po.supplierName?.toLowerCase().contains(query) ?? false)).toList();
                  }

                  if (statusFilter != null) {
                    filtered = filtered.where((po) => po.status == statusFilter.code).toList();
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }

                  return _buildPOList(context, ref, filtered);
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
            Icon(FluentIcons.shopping_cart, size: 48, color: Colors.grey[100]),
            const SizedBox(height: 16),
            Text('No purchase orders found', style: TextStyle(color: Colors.grey[100])),
            const SizedBox(height: 8),
            FilledButton(
              child: const Text('Create First Purchase Order'),
              onPressed: () => _showCreatePODialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOList(BuildContext context, WidgetRef ref, List<PurchaseOrderWithSupplier> purchaseOrders) {
    return Card(
      child: ListView.builder(
        itemCount: purchaseOrders.length,
        itemBuilder: (context, index) {
          final po = purchaseOrders[index];
          final status = OrderStatusExtension.fromString(po.status);

          return ListTile.selectable(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                FluentIcons.clipboard_list,
                color: _getStatusColor(status),
              ),
            ),
            title: Row(
              children: [
                Text(po.poNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${po.supplierName ?? "No supplier"} | ${Formatters.date(po.createdAt)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatters.currency(po.totalAmount),
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(FluentIcons.view),
                  onPressed: () => _showPODetailDialog(context, ref, po.purchaseOrder.id),
                ),
                if (po.status == OrderStatus.draft.code) ...[
                  IconButton(
                    icon: const Icon(FluentIcons.delete),
                    onPressed: () => _confirmDelete(context, ref, po),
                  ),
                ],
              ],
            ),
            onPressed: () => _showPODetailDialog(context, ref, po.purchaseOrder.id),
          );
        },
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return Colors.grey;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.partiallyReceived:
        return AppTheme.warningColor;
      case OrderStatus.received:
        return AppTheme.successColor;
      case OrderStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  void _showCreatePODialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreatePurchaseOrderDialog(),
    );
  }

  void _showPODetailDialog(BuildContext context, WidgetRef ref, String poId) {
    showDialog(
      context: context,
      builder: (context) => PurchaseOrderDetailDialog(poId: poId),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PurchaseOrderWithSupplier po) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Purchase Order'),
        content: Text('Are you sure you want to delete "${po.poNumber}"?'),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Delete'),
            onPressed: () {
              ref.read(purchaseOrderFormProvider.notifier).deletePurchaseOrder(po.purchaseOrder.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// Create Purchase Order Dialog
class CreatePurchaseOrderDialog extends ConsumerStatefulWidget {
  const CreatePurchaseOrderDialog({super.key});

  @override
  ConsumerState<CreatePurchaseOrderDialog> createState() => _CreatePurchaseOrderDialogState();
}

class _CreatePurchaseOrderDialogState extends ConsumerState<CreatePurchaseOrderDialog> {
  String? _selectedSupplierId;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final formState = ref.watch(purchaseOrderFormProvider);

    ref.listen<PurchaseOrderFormState>(purchaseOrderFormProvider, (previous, next) {
      if (next.isSuccess && next.createdPO != null) {
        Navigator.of(context).pop();
        ref.read(purchaseOrderFormProvider.notifier).reset();
        // Open the detail dialog for the new PO
        showDialog(
          context: context,
          builder: (context) => PurchaseOrderDetailDialog(poId: next.createdPO!.id),
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
      title: const Text('Create Purchase Order'),
      constraints: const BoxConstraints(maxWidth: 400),
      content: Column(
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
                onChanged: (value) => setState(() => _selectedSupplierId = value),
                isExpanded: true,
              ),
              loading: () => const ProgressRing(),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Notes',
            child: TextBox(
              controller: _notesController,
              placeholder: 'Enter notes',
              maxLines: 3,
            ),
          ),
        ],
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
                  ref.read(purchaseOrderFormProvider.notifier).createPurchaseOrder(
                        supplierId: _selectedSupplierId!,
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

// Purchase Order Detail Dialog
class PurchaseOrderDetailDialog extends ConsumerStatefulWidget {
  final String poId;

  const PurchaseOrderDetailDialog({super.key, required this.poId});

  @override
  ConsumerState<PurchaseOrderDetailDialog> createState() => _PurchaseOrderDetailDialogState();
}

class _PurchaseOrderDetailDialogState extends ConsumerState<PurchaseOrderDetailDialog> {
  @override
  Widget build(BuildContext context) {
    final poDetailAsync = ref.watch(purchaseOrderDetailProvider(widget.poId));

    return ContentDialog(
      title: const Text('Purchase Order Details'),
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
      content: poDetailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Purchase order not found'));
          }
          return _buildDetail(context, detail);
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

  Widget _buildDetail(BuildContext context, PurchaseOrderDetail detail) {
    final status = OrderStatusExtension.fromString(detail.purchaseOrder.status);

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
                    detail.purchaseOrder.poNumber,
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 4),
                  Text('Supplier: ${detail.supplier?.name ?? "N/A"}'),
                  Text('Date: ${Formatters.date(detail.purchaseOrder.createdAt)}'),
                ],
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
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (status == OrderStatus.draft) ...[
                    FilledButton(
                      child: const Text('Confirm Order'),
                      onPressed: () {
                        ref.read(purchaseOrderFormProvider.notifier).updateStatus(
                              widget.poId,
                              OrderStatus.confirmed,
                            );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Items section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items', style: FluentTheme.of(context).typography.bodyStrong),
              if (status == OrderStatus.draft)
                IconButton(
                  icon: const Icon(FluentIcons.add),
                  onPressed: () => _showAddItemDialog(context, widget.poId),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (detail.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No items added yet')),
            )
          else
            ...detail.items.map((item) => _buildItemTile(context, item, status)),

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

  Widget _buildItemTile(BuildContext context, PurchaseOrderItemWithProduct item, OrderStatus status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
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
                if (item.receivedQuantity > 0)
                  Text('Received: ${item.receivedQuantity}',
                       style: TextStyle(color: AppTheme.successColor)),
              ],
            ),
            if (status == OrderStatus.draft) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(FluentIcons.delete, size: 16),
                onPressed: () {
                  ref.read(purchaseOrderFormProvider.notifier).deleteItem(
                        item.item.id,
                        widget.poId,
                      );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return Colors.grey;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.partiallyReceived:
        return AppTheme.warningColor;
      case OrderStatus.received:
        return AppTheme.successColor;
      case OrderStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  void _showAddItemDialog(BuildContext context, String poId) {
    showDialog(
      context: context,
      builder: (context) => AddPOItemDialog(poId: poId),
    );
  }
}

// Add PO Item Dialog
class AddPOItemDialog extends ConsumerStatefulWidget {
  final String poId;

  const AddPOItemDialog({super.key, required this.poId});

  @override
  ConsumerState<AddPOItemDialog> createState() => _AddPOItemDialogState();
}

class _AddPOItemDialogState extends ConsumerState<AddPOItemDialog> {
  String? _selectedProductId;
  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final formState = ref.watch(purchaseOrderFormProvider);

    ref.listen<PurchaseOrderFormState>(purchaseOrderFormProvider, (previous, next) {
      if (next.isSuccess) {
        Navigator.of(context).pop();
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
      title: const Text('Add Item'),
      constraints: const BoxConstraints(maxWidth: 400),
      content: Column(
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
                  setState(() => _selectedProductId = value);
                  // Auto-fill cost from product
                  final product = products.firstWhere((p) => p.id == value);
                  _unitCostController.text = product.costPrice.toString();
                },
                isExpanded: true,
              ),
              loading: () => const ProgressRing(),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InfoLabel(
                  label: 'Quantity *',
                  child: TextBox(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
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
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: formState.isLoading || _selectedProductId == null
              ? null
              : () {
                  final quantity = int.tryParse(_quantityController.text) ?? 0;
                  final unitCost = double.tryParse(_unitCostController.text) ?? 0;

                  if (quantity <= 0 || unitCost <= 0) {
                    displayInfoBar(context, builder: (context, close) {
                      return const InfoBar(
                        title: Text('Validation Error'),
                        content: Text('Quantity and unit cost must be greater than 0'),
                        severity: InfoBarSeverity.warning,
                      );
                    });
                    return;
                  }

                  ref.read(purchaseOrderFormProvider.notifier).addItem(
                        purchaseOrderId: widget.poId,
                        productId: _selectedProductId!,
                        quantity: quantity,
                        unitCost: unitCost,
                      );
                },
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
}
