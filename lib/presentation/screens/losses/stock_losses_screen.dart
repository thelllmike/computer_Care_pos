import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/stock_loss_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/local/tables/stock_losses_table.dart';
import '../../providers/core/database_provider.dart';
import '../../providers/expenses/expense_provider.dart';
import '../../providers/losses/stock_loss_provider.dart';
import '../../providers/inventory/product_provider.dart';

class StockLossesScreen extends ConsumerStatefulWidget {
  const StockLossesScreen({super.key});

  @override
  ConsumerState<StockLossesScreen> createState() => _StockLossesScreenState();
}

class _StockLossesScreenState extends ConsumerState<StockLossesScreen> {
  LossType? _selectedType;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final params = DateRangeParams(startDate: _startDate, endDate: _endDate);
    final summaryAsync = ref.watch(stockLossSummaryProvider(params));
    final lossesAsync = ref.watch(stockLossesByDateRangeProvider(params));

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Stock Losses'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Record Loss'),
              onPressed: () => _showLossDialog(context, ref),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(stockLossesProvider);
                ref.invalidate(stockLossSummaryProvider(params));
                ref.invalidate(stockLossesByDateRangeProvider(params));
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
                        title: 'Total Loss Amount',
                        value: Formatters.currency(summary.totalLossAmount),
                        icon: FluentIcons.money,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Items Lost',
                        value: summary.totalLossCount.toString(),
                        icon: FluentIcons.product,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Damaged',
                        value: summary.getLossCountByType(LossType.damaged).toString(),
                        icon: FluentIcons.warning,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Lost/Stolen',
                        value: (summary.getLossCountByType(LossType.lost) +
                                summary.getLossCountByType(LossType.stolen))
                            .toString(),
                        icon: FluentIcons.error_badge,
                        color: Colors.purple,
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

              // Filters
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.filter),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            const Text('From: '),
                            DatePicker(
                              selected: _startDate,
                              onChanged: (date) {
                                setState(() => _startDate = date);
                              },
                            ),
                            const SizedBox(width: 16),
                            const Text('To: '),
                            DatePicker(
                              selected: _endDate,
                              onChanged: (date) {
                                setState(() => _endDate = date);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ComboBox<LossType?>(
                        placeholder: const Text('All Types'),
                        value: _selectedType,
                        items: [
                          const ComboBoxItem(value: null, child: Text('All Types')),
                          ...LossType.values.map((t) => ComboBoxItem(
                                value: t,
                                child: Text(t.displayName),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedType = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Loss type breakdown
              summaryAsync.when(
                data: (summary) {
                  if (summary.totalLossCount == 0) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loss Type Breakdown',
                          style: FluentTheme.of(context).typography.subtitle),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: LossType.values.map((type) {
                          final amount = summary.getLossAmountByType(type);
                          final count = summary.getLossCountByType(type);
                          if (count == 0) return const SizedBox.shrink();
                          final percentage = summary.totalLossAmount > 0
                              ? (amount / summary.totalLossAmount * 100)
                              : 0.0;
                          return _TypeChip(
                            type: type.displayName,
                            amount: amount,
                            count: count,
                            percentage: percentage,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Losses list
              Text('Stock Losses', style: FluentTheme.of(context).typography.subtitle),
              const SizedBox(height: 12),
              lossesAsync.when(
                data: (losses) {
                  var filtered = losses;
                  if (_selectedType != null) {
                    filtered = losses
                        .where((l) => l.lossType == _selectedType)
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return Card(
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.warning,
                                  size: 48, color: Colors.grey[100]),
                              const SizedBox(height: 16),
                              Text('No stock losses found',
                                  style: TextStyle(color: Colors.grey[100])),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: Column(
                      children: filtered
                          .map((loss) => _LossTile(loss: loss))
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

  void _showLossDialog(BuildContext context, WidgetRef ref) {
    ref.read(stockLossFormProvider.notifier).clear();
    showDialog(
      context: context,
      builder: (context) => const _StockLossFormDialog(),
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

// Type Chip Widget
class _TypeChip extends StatelessWidget {
  final String type;
  final double amount;
  final int count;
  final double percentage;

  const _TypeChip({
    required this.type,
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(amount),
            style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            '$count items (${percentage.toStringAsFixed(1)}%)',
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
        ],
      ),
    );
  }
}

// Loss Tile Widget
class _LossTile extends StatelessWidget {
  final StockLossWithProduct loss;

  const _LossTile({required this.loss});

  @override
  Widget build(BuildContext context) {
    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getLossTypeIcon(loss.lossType),
            color: AppTheme.errorColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loss.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  loss.lossNumber,
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                ),
              ],
            ),
          ),
          Text(
            Formatters.currency(loss.totalLossAmount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          _LossTypeBadge(type: loss.lossType),
          const SizedBox(width: 8),
          Text(
            'Qty: ${loss.quantity}',
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.date(loss.lossDate),
            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
          ),
        ],
      ),
    );
  }

  IconData _getLossTypeIcon(LossType type) {
    switch (type) {
      case LossType.damaged:
        return FluentIcons.warning;
      case LossType.lost:
        return FluentIcons.search;
      case LossType.stolen:
        return FluentIcons.lock;
      case LossType.expired:
        return FluentIcons.clock;
    }
  }
}

class _LossTypeBadge extends StatelessWidget {
  final LossType type;

  const _LossTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case LossType.damaged:
        color = Colors.red;
        break;
      case LossType.lost:
        color = Colors.orange;
        break;
      case LossType.stolen:
        color = Colors.purple;
        break;
      case LossType.expired:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Stock Loss Form Dialog
class _StockLossFormDialog extends ConsumerStatefulWidget {
  const _StockLossFormDialog();

  @override
  ConsumerState<_StockLossFormDialog> createState() =>
      _StockLossFormDialogState();
}

class _StockLossFormDialogState extends ConsumerState<_StockLossFormDialog> {
  final _reasonController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();
  final _notesController = TextEditingController();
  String _productSearchQuery = '';

  @override
  void dispose() {
    _reasonController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(stockLossFormProvider);
    final productsAsync = ref.watch(productsWithInventoryProvider);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600),
      title: const Text('Record Stock Loss'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product selection
            InfoLabel(
              label: 'Product *',
              child: productsAsync.when(
                data: (products) {
                  final filtered = _productSearchQuery.isEmpty
                      ? products
                      : products
                          .where((p) =>
                              p.product.name
                                  .toLowerCase()
                                  .contains(_productSearchQuery.toLowerCase()) ||
                              p.product.code
                                  .toLowerCase()
                                  .contains(_productSearchQuery.toLowerCase()))
                          .toList();

                  return AutoSuggestBox<ProductWithInventory>(
                    placeholder: 'Search product...',
                    items: filtered
                        .map((p) => AutoSuggestBoxItem<ProductWithInventory>(
                              value: p,
                              label: '${p.product.name} (${p.product.code})',
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text('${p.product.name} (${p.product.code})'),
                                  ),
                                  Text(
                                    'Stock: ${p.quantityOnHand}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.quantityOnHand > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onSelected: (item) {
                      if (item.value != null) {
                        final product = item.value!;
                        ref.read(stockLossFormProvider.notifier).setProduct(
                              product.product.id,
                              product.product.name,
                              product.wac,
                            );
                        _unitCostController.text = product.wac.toStringAsFixed(2);
                      }
                    },
                    onChanged: (text, reason) {
                      setState(() => _productSearchQuery = text);
                    },
                  );
                },
                loading: () => const ProgressRing(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            if (formState.productName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected: ${formState.productName}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Loss Type
            InfoLabel(
              label: 'Loss Type *',
              child: ComboBox<LossType>(
                value: formState.lossType,
                items: LossType.values
                    .map((t) => ComboBoxItem(
                          value: t,
                          child: Text(t.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(stockLossFormProvider.notifier).setLossType(value);
                  }
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 16),

            // Quantity and Unit Cost
            Row(
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Quantity *',
                    child: TextBox(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final qty = int.tryParse(value) ?? 1;
                        ref.read(stockLossFormProvider.notifier).setQuantity(qty);
                      },
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
                      onChanged: (value) {
                        final cost = double.tryParse(value) ?? 0;
                        ref.read(stockLossFormProvider.notifier).setUnitCost(cost);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total Loss Amount
            Card(
              backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Loss Amount:'),
                    Text(
                      Formatters.currency(formState.totalLossAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reason
            InfoLabel(
              label: 'Loss Reason *',
              child: TextBox(
                controller: _reasonController,
                placeholder: 'Describe why the loss occurred...',
                maxLines: 2,
                onChanged: (value) {
                  ref.read(stockLossFormProvider.notifier).setLossReason(value);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Loss Date
            InfoLabel(
              label: 'Loss Date',
              child: DatePicker(
                selected: formState.lossDate,
                onChanged: (date) {
                  ref.read(stockLossFormProvider.notifier).setLossDate(date);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            InfoLabel(
              label: 'Additional Notes',
              child: TextBox(
                controller: _notesController,
                maxLines: 2,
                placeholder: 'Optional notes',
                onChanged: (value) {
                  ref
                      .read(stockLossFormProvider.notifier)
                      .setNotes(value.isEmpty ? null : value);
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
                  final loss =
                      await ref.read(stockLossFormProvider.notifier).saveStockLoss();
                  if (loss != null && mounted) {
                    Navigator.of(context).pop();
                    displayInfoBar(context, builder: (context, close) {
                      return InfoBar(
                        title: const Text('Success'),
                        content: Text('Stock loss ${loss.lossNumber} recorded'),
                        severity: InfoBarSeverity.success,
                        onClose: close,
                      );
                    });
                  }
                },
          child: formState.isSaving
              ? const SizedBox(
                  width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : const Text('Record Loss'),
        ),
      ],
    );
  }
}
