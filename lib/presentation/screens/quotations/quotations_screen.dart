import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/payment_method.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/quotation_dao.dart';
import '../../../data/local/daos/sales_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../../services/printing/receipt_printer.dart';
import '../../providers/inventory/customer_provider.dart';
import '../../providers/inventory/product_provider.dart';
import '../../providers/sales/quotation_provider.dart';
import '../../providers/core/database_provider.dart';
import '../../providers/core/settings_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _statusFilterProvider = StateProvider<QuotationStatus?>((ref) => null);

class QuotationsScreen extends ConsumerWidget {
  const QuotationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final statusFilter = ref.watch(_statusFilterProvider);
    final quotationsAsync = ref.watch(quotationsProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Quotations'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Quotation'),
              onPressed: () => _showCreateQuotationDialog(context, ref),
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          // Search and filters
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: TextBox(
                    placeholder: 'Search quotations...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 16),
                    ),
                    onChanged: (value) => ref.read(_searchQueryProvider.notifier).state = value,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  child: ComboBox<QuotationStatus?>(
                    placeholder: const Text('All Status'),
                    value: statusFilter,
                    items: [
                      const ComboBoxItem(value: null, child: Text('All Status')),
                      ...QuotationStatus.values.map((s) => ComboBoxItem(
                            value: s,
                            child: Text(s.name.toUpperCase()),
                          )),
                    ],
                    onChanged: (value) => ref.read(_statusFilterProvider.notifier).state = value,
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(FluentIcons.refresh),
                  onPressed: () => ref.invalidate(quotationsProvider),
                ),
              ],
            ),
          ),
          // Quotation list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: quotationsAsync.when(
                data: (quotations) {
                  // Filter by status
                  var filtered = quotations;
                  if (statusFilter != null) {
                    filtered = quotations.where((q) => q.status == statusFilter!.code).toList();
                  }

                  // Filter by search
                  if (searchQuery.isNotEmpty) {
                    filtered = filtered.where((q) =>
                        q.quotationNumber.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        (q.customerName?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
                    ).toList();
                  }

                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }

                  return _buildQuotationList(context, ref, filtered);
                },
                loading: () => const Center(child: ProgressRing()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.document, size: 48, color: Colors.grey[100]),
            const SizedBox(height: 16),
            Text('No quotations found', style: TextStyle(color: Colors.grey[100])),
            const SizedBox(height: 8),
            FilledButton(
              child: const Text('Create Quotation'),
              onPressed: () => _showCreateQuotationDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationList(BuildContext context, WidgetRef ref, List<QuotationWithCustomer> quotations) {
    return Card(
      child: ListView.separated(
        itemCount: quotations.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final q = quotations[index];
          return _QuotationTile(
            quotation: q,
            onTap: () => _showQuotationDetailDialog(context, ref, q.quotation.id),
          );
        },
      ),
    );
  }

  void _showCreateQuotationDialog(BuildContext context, WidgetRef ref) {
    // Clear the form
    ref.read(quotationFormProvider.notifier).clear();

    showDialog(
      context: context,
      builder: (context) => const _QuotationFormDialog(),
    ).then((_) {
      ref.invalidate(quotationsProvider);
    });
  }

  void _showQuotationDetailDialog(BuildContext context, WidgetRef ref, String quotationId) {
    showDialog(
      context: context,
      builder: (context) => _QuotationDetailDialog(quotationId: quotationId),
    ).then((_) {
      ref.invalidate(quotationsProvider);
    });
  }
}

// Quotation Tile
class _QuotationTile extends StatelessWidget {
  final QuotationWithCustomer quotation;
  final VoidCallback onTap;

  const _QuotationTile({
    required this.quotation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getStatusColor(quotation.status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          FluentIcons.document,
          color: _getStatusColor(quotation.status),
        ),
      ),
      title: Row(
        children: [
          Text(
            quotation.quotationNumber,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(quotation.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              quotation.status,
              style: TextStyle(
                fontSize: 10,
                color: _getStatusColor(quotation.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quotation.customerName ?? 'Walk-in Customer'),
          Text(
            'Valid until: ${Formatters.date(quotation.validUntil)}',
            style: TextStyle(
              fontSize: 11,
              color: quotation.isExpired ? AppTheme.errorColor : null,
            ),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Formatters.currency(quotation.totalAmount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            Formatters.date(quotation.quotationDate),
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
      onPressed: onTap,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return Colors.grey[100]!;
      case 'SENT':
        return Colors.blue;
      case 'ACCEPTED':
        return AppTheme.successColor;
      case 'REJECTED':
        return AppTheme.errorColor;
      case 'EXPIRED':
        return AppTheme.warningColor;
      case 'CONVERTED':
        return AppTheme.primaryColor;
      default:
        return Colors.grey[100]!;
    }
  }
}

// Quotation Form Dialog
class _QuotationFormDialog extends ConsumerStatefulWidget {
  final String? quotationId;

  const _QuotationFormDialog({this.quotationId});

  @override
  ConsumerState<_QuotationFormDialog> createState() => _QuotationFormDialogState();
}

class _QuotationFormDialogState extends ConsumerState<_QuotationFormDialog> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.quotationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(quotationFormProvider.notifier).loadQuotation(widget.quotationId!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(quotationFormProvider);
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
      title: Text(formState.isEditing ? 'Edit Quotation' : 'New Quotation'),
      content: formState.isLoading
          ? const Center(child: ProgressRing())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Customer and validity date
                  Row(
                    children: [
                      Expanded(
                        child: InfoLabel(
                          label: 'Customer (Optional) - Search by name or phone',
                          child: customersAsync.when(
                            data: (customers) => Row(
                              children: [
                                Expanded(
                                  child: AutoSuggestBox<String>(
                                    placeholder: 'Search by name or phone...',
                                    items: [
                                      AutoSuggestBoxItem<String>(
                                        value: '',
                                        label: 'Walk-in Customer',
                                      ),
                                      ...customers.map((c) => AutoSuggestBoxItem<String>(
                                            value: c.id,
                                            label: '${c.name} - ${c.phone ?? ''} - ${c.code}',
                                          )),
                                    ],
                                    onSelected: (item) {
                                      if (item.value == null || item.value!.isEmpty) {
                                        ref.read(quotationFormProvider.notifier).setCustomer(null, null);
                                      } else {
                                        final customer = customers.firstWhere((c) => c.id == item.value);
                                        ref.read(quotationFormProvider.notifier).setCustomer(
                                              customer.id,
                                              customer.name,
                                            );
                                      }
                                    },
                                  ),
                                ),
                                if (formState.customerName != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          formState.customerName!,
                                          style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () => ref.read(quotationFormProvider.notifier).setCustomer(null, null),
                                          child: Icon(FluentIcons.cancel, size: 12, color: AppTheme.primaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            loading: () => const ProgressRing(),
                            error: (e, _) => Text('Error: $e'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InfoLabel(
                          label: 'Valid Until',
                          child: DatePicker(
                            selected: formState.validUntil,
                            onChanged: (date) {
                              ref.read(quotationFormProvider.notifier).setValidUntil(date);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Add product
                  Text('Add Products', style: FluentTheme.of(context).typography.subtitle),
                  const SizedBox(height: 8),
                  productsAsync.when(
                    data: (products) => Row(
                      children: [
                        Expanded(
                          child: AutoSuggestBox<Product>(
                            controller: _searchController,
                            placeholder: 'Search product by name or code...',
                            items: products.map((p) => AutoSuggestBoxItem<Product>(
                                  value: p,
                                  label: '${p.name} (${p.code})',
                                )).toList(),
                            onSelected: (item) {
                              if (item.value != null) {
                                ref.read(quotationFormProvider.notifier).addItem(
                                      productId: item.value!.id,
                                      productName: item.value!.name,
                                      productCode: item.value!.code,
                                      unitPrice: item.value!.sellingPrice,
                                    );
                                _searchController.clear();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    loading: () => const ProgressRing(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),

                  // Items list
                  if (formState.items.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[40]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.grey[20],
                            child: Row(
                              children: [
                                const Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                                const Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                                const Expanded(child: Text('Price', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                                const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                                const SizedBox(width: 40),
                              ],
                            ),
                          ),
                          // Items
                          ...formState.items.map((item) => _QuotationItemRow(
                                item: item,
                                onQuantityChanged: (qty) {
                                  ref.read(quotationFormProvider.notifier).updateItemQuantity(item.productId, qty);
                                },
                                onPriceChanged: (price) {
                                  ref.read(quotationFormProvider.notifier).updateItemPrice(item.productId, price);
                                },
                                onRemove: () {
                                  ref.read(quotationFormProvider.notifier).removeItem(item.productId);
                                },
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Totals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 300,
                          child: Column(
                            children: [
                              _TotalRow(label: 'Subtotal', value: formState.subtotal),
                              _TotalRow(
                                label: 'Discount',
                                value: formState.discountAmount,
                                isEditable: true,
                                onChanged: (value) {
                                  ref.read(quotationFormProvider.notifier).setDiscount(value);
                                },
                              ),
                              const Divider(),
                              _TotalRow(label: 'Total', value: formState.total, isBold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Card(
                      child: SizedBox(
                        height: 150,
                        child: Center(
                          child: Text('No items added yet', style: TextStyle(color: Colors.grey[100])),
                        ),
                      ),
                    ),
                  ],

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
          onPressed: formState.isSaving || formState.isEmpty
              ? null
              : () async {
                  final quotation = await ref.read(quotationFormProvider.notifier).saveQuotation();
                  if (quotation != null && context.mounted) {
                    Navigator.of(context).pop();
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Success'),
                        content: Text('Quotation ${quotation.quotationNumber} saved'),
                        severity: InfoBarSeverity.success,
                        action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
                      );
                    });
                  }
                },
          child: formState.isSaving
              ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : const Text('Save Quotation'),
        ),
      ],
    );
  }
}

// Quotation Item Row
class _QuotationItemRow extends StatelessWidget {
  final QuotationItemState item;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onRemove;

  const _QuotationItemRow({
    required this.item,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[30]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(item.productCode, style: TextStyle(fontSize: 11, color: Colors.grey[100])),
              ],
            ),
          ),
          Expanded(
            child: NumberBox<int>(
              value: item.quantity,
              min: 1,
              max: 9999,
              mode: SpinButtonPlacementMode.none,
              onChanged: (value) => onQuantityChanged(value ?? 1),
            ),
          ),
          Expanded(
            child: NumberBox<double>(
              value: item.unitPrice,
              min: 0,
              mode: SpinButtonPlacementMode.none,
              onChanged: (value) => onPriceChanged(value ?? 0),
            ),
          ),
          Expanded(
            child: Text(
              Formatters.currency(item.lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(FluentIcons.delete, color: AppTheme.errorColor),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

// Total Row
class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final bool isEditable;
  final ValueChanged<double>? onChanged;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isEditable = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : null),
          ),
          isEditable
              ? SizedBox(
                  width: 100,
                  child: NumberBox<double>(
                    value: value,
                    min: 0,
                    mode: SpinButtonPlacementMode.none,
                    onChanged: (v) => onChanged?.call(v ?? 0),
                  ),
                )
              : Text(
                  Formatters.currency(value),
                  style: TextStyle(fontWeight: isBold ? FontWeight.bold : null),
                ),
        ],
      ),
    );
  }
}

// Quotation Detail Dialog
class _QuotationDetailDialog extends ConsumerWidget {
  final String quotationId;

  const _QuotationDetailDialog({required this.quotationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(quotationDetailProvider(quotationId));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
      title: const Text('Quotation Details'),
      content: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Quotation not found'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(detail.quotationNumber, style: FluentTheme.of(context).typography.subtitle),
                          const SizedBox(height: 4),
                          Text('Customer: ${detail.customerName ?? 'Walk-in'}'),
                          Text('Date: ${Formatters.date(detail.quotationDate)}'),
                          Text('Valid Until: ${Formatters.date(detail.validUntil)}'),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(detail.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        detail.status,
                        style: TextStyle(
                          color: _getStatusColor(detail.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Items
                Text('Items', style: FluentTheme.of(context).typography.bodyStrong),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[40]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey[20],
                        child: Row(
                          children: [
                            const Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600))),
                            const Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            const Expanded(child: Text('Price', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                            const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      ...detail.items.map((item) => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[30]!)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName),
                                      Text(item.productCode, style: TextStyle(fontSize: 11, color: Colors.grey[100])),
                                    ],
                                  ),
                                ),
                                Expanded(child: Text('${item.quantity}', textAlign: TextAlign.center)),
                                Expanded(child: Text(Formatters.currency(item.unitPrice), textAlign: TextAlign.right)),
                                Expanded(child: Text(Formatters.currency(item.totalPrice), textAlign: TextAlign.right)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Totals
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 250,
                      child: Column(
                        children: [
                          _TotalRow(label: 'Subtotal', value: detail.subtotal),
                          _TotalRow(label: 'Discount', value: detail.discountAmount),
                          _TotalRow(label: 'Tax', value: detail.taxAmount),
                          const Divider(),
                          _TotalRow(label: 'Total', value: detail.totalAmount, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (detailAsync.valueOrNull != null)
          Button(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.print, size: 16),
                SizedBox(width: 8),
                Text('Print'),
              ],
            ),
            onPressed: () async {
              final detail = detailAsync.valueOrNull!;
              final companySettings = await ref.read(companySettingsProvider.future);
              await ReceiptPrinter.printQuotation(
                detail: detail,
                companyName: companySettings.name.isNotEmpty ? companySettings.name : 'Your Company',
                companyAddress: companySettings.address.isNotEmpty ? companySettings.address : '',
                companyPhone: companySettings.phone.isNotEmpty ? companySettings.phone : '',
                companyEmail: companySettings.email.isNotEmpty ? companySettings.email : '',
              );
            },
          ),
        if (detailAsync.valueOrNull?.canConvert ?? false) ...[
          FilledButton(
            child: const Text('Convert to Invoice'),
            onPressed: () => _showConvertDialog(context, ref, quotationId),
          ),
        ],
        if (detailAsync.valueOrNull?.quotation.status == 'DRAFT') ...[
          Button(
            child: const Text('Edit'),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(quotationFormProvider.notifier).loadQuotation(quotationId);
              showDialog(
                context: context,
                builder: (context) => _QuotationFormDialog(quotationId: quotationId),
              );
            },
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return Colors.grey[100]!;
      case 'SENT':
        return Colors.blue;
      case 'ACCEPTED':
        return AppTheme.successColor;
      case 'REJECTED':
        return AppTheme.errorColor;
      case 'EXPIRED':
        return AppTheme.warningColor;
      case 'CONVERTED':
        return AppTheme.primaryColor;
      default:
        return Colors.grey[100]!;
    }
  }

  void _showConvertDialog(BuildContext context, WidgetRef ref, String quotationId) {
    showDialog(
      context: context,
      builder: (context) => _ConvertToSaleDialog(quotationId: quotationId),
    ).then((_) {
      Navigator.of(context).pop(); // Close detail dialog
      ref.invalidate(quotationsProvider);
    });
  }
}

// Convert to Sale Dialog
class _ConvertToSaleDialog extends ConsumerStatefulWidget {
  final String quotationId;

  const _ConvertToSaleDialog({required this.quotationId});

  @override
  ConsumerState<_ConvertToSaleDialog> createState() => _ConvertToSaleDialogState();
}

class _ConvertToSaleDialogState extends ConsumerState<_ConvertToSaleDialog> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _amountController = TextEditingController();
  bool _isCredit = false;

  @override
  void initState() {
    super.initState();
    ref.read(convertToSaleProvider.notifier).reset();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convertState = ref.watch(convertToSaleProvider);
    final detailAsync = ref.watch(quotationDetailProvider(widget.quotationId));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 400),
      title: const Text('Convert to Invoice'),
      content: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Quotation not found'));
          }

          if (_amountController.text.isEmpty) {
            _amountController.text = detail.totalAmount.toString();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Amount: ${Formatters.currency(detail.totalAmount)}',
                  style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 16),

              // Credit sale toggle
              Checkbox(
                checked: _isCredit,
                onChanged: detail.quotation.customerId != null
                    ? (value) => setState(() => _isCredit = value ?? false)
                    : null,
                content: const Text('Credit Sale'),
              ),
              if (detail.quotation.customerId == null)
                Text('Credit sales require a customer',
                    style: TextStyle(fontSize: 11, color: Colors.grey[100])),
              const SizedBox(height: 16),

              if (!_isCredit) ...[
                InfoLabel(
                  label: 'Payment Method',
                  child: ComboBox<PaymentMethod>(
                    value: _paymentMethod,
                    items: PaymentMethod.values.map((m) => ComboBoxItem(
                          value: m,
                          child: Text(m.displayName),
                        )).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _paymentMethod = value);
                    },
                    isExpanded: true,
                  ),
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Amount Received',
                  child: TextBox(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],

              if (convertState.error != null) ...[
                const SizedBox(height: 16),
                InfoBar(
                  title: const Text('Error'),
                  content: Text(convertState.error!),
                  severity: InfoBarSeverity.error,
                ),
              ],

              if (convertState.isSuccess) ...[
                const SizedBox(height: 16),
                InfoBar(
                  title: const Text('Success'),
                  content: Text('Invoice ${convertState.completedSale?.invoiceNumber} created'),
                  severity: InfoBarSeverity.success,
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (!convertState.isSuccess)
          FilledButton(
            onPressed: convertState.isProcessing
                ? null
                : () async {
                    final amount = double.tryParse(_amountController.text) ?? 0;
                    final payments = _isCredit
                        ? <PaymentEntry>[]
                        : [PaymentEntry(method: _paymentMethod, amount: amount)];

                    await ref.read(convertToSaleProvider.notifier).convertToSale(
                          quotationId: widget.quotationId,
                          payments: payments,
                          isCredit: _isCredit,
                        );
                  },
            child: convertState.isProcessing
                ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
                : const Text('Convert'),
          ),
        if (convertState.isSuccess)
          FilledButton(
            child: const Text('Done'),
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}
