import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/serial_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/inventory_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../providers/inventory/inventory_provider.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _showLowStockOnlyProvider = StateProvider<bool>((ref) => false);
final _selectedTabProvider = StateProvider<int>((ref) => 0);

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_selectedTabProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Inventory Management'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(inventoryProvider);
                ref.invalidate(lowStockProvider);
                ref.invalidate(inventoryStatsProvider);
              },
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          // Stats cards
          _buildStatsCards(ref),
          const SizedBox(height: 16),
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildTabButton('Stock Levels', FluentIcons.product_list, 0, selectedTab, ref),
                const SizedBox(width: 8),
                _buildTabButton('Serial Numbers', FluentIcons.generic_scan, 1, selectedTab, ref),
                const SizedBox(width: 8),
                _buildTabButton('Low Stock Alerts', FluentIcons.warning, 2, selectedTab, ref),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildTabContent(selectedTab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(WidgetRef ref) {
    final statsAsync = ref.watch(inventoryStatsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: statsAsync.when(
        data: (stats) => Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Products',
                value: stats.totalProducts.toString(),
                icon: FluentIcons.product,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Low Stock Items',
                value: stats.lowStockCount.toString(),
                icon: FluentIcons.warning,
                color: stats.lowStockCount > 0 ? AppTheme.errorColor : AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Total Value',
                value: Formatters.currency(stats.totalValue),
                icon: FluentIcons.money,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Serialized Units',
                value: stats.serializedCount.toString(),
                icon: FluentIcons.generic_scan,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index, int selectedTab, WidgetRef ref) {
    final isSelected = selectedTab == index;
    return ToggleButton(
      checked: isSelected,
      onChanged: (_) => ref.read(_selectedTabProvider.notifier).state = index,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(int selectedTab) {
    switch (selectedTab) {
      case 0:
        return const _StockLevelsTab();
      case 1:
        return const _SerialNumbersTab();
      case 2:
        return const _LowStockTab();
      default:
        return const _StockLevelsTab();
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FluentTheme.of(context).typography.caption),
              Text(value, style: FluentTheme.of(context).typography.subtitle),
            ],
          ),
        ],
      ),
    );
  }
}

// Stock Levels Tab
class _StockLevelsTab extends ConsumerWidget {
  const _StockLevelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final showLowStockOnly = ref.watch(_showLowStockOnlyProvider);
    final inventoryAsync = ref.watch(inventoryProvider);

    return Column(
      children: [
        // Search and filters
        Row(
          children: [
            Expanded(
              child: TextBox(
                placeholder: 'Search products...',
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
            Checkbox(
              checked: showLowStockOnly,
              content: const Text('Low Stock Only'),
              onChanged: (value) {
                ref.read(_showLowStockOnlyProvider.notifier).state = value ?? false;
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Inventory list
        Expanded(
          child: inventoryAsync.when(
            data: (inventory) {
              var filtered = inventory;

              if (searchQuery.isNotEmpty) {
                final query = searchQuery.toLowerCase();
                filtered = filtered.where((i) =>
                    i.product.name.toLowerCase().contains(query) ||
                    i.product.code.toLowerCase().contains(query)).toList();
              }

              if (showLowStockOnly) {
                filtered = filtered.where((i) => i.isLowStock).toList();
              }

              if (filtered.isEmpty) {
                return const Center(child: Text('No inventory items found'));
              }

              return Card(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildInventoryTile(context, ref, item);
                  },
                ),
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTile(BuildContext context, WidgetRef ref, InventoryWithProduct item) {
    final isLowStock = item.isLowStock;

    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isLowStock
              ? AppTheme.errorColor.withValues(alpha: 0.1)
              : AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          FluentIcons.product,
          color: isLowStock ? AppTheme.errorColor : AppTheme.primaryColor,
        ),
      ),
      title: Row(
        children: [
          Text(item.product.name),
          if (isLowStock) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'LOW STOCK',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (item.product.requiresSerial) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SERIALIZED',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text('Code: ${item.product.code}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Qty: ${item.quantityOnHand}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isLowStock ? AppTheme.errorColor : null,
                ),
              ),
              Text(
                'WAC: ${Formatters.currency(item.wac)}',
                style: FluentTheme.of(context).typography.caption,
              ),
              Text(
                'Value: ${Formatters.currency(item.totalCost)}',
                style: FluentTheme.of(context).typography.caption,
              ),
            ],
          ),
          const SizedBox(width: 16),
          if (item.product.requiresSerial)
            IconButton(
              icon: Icon(FluentIcons.generic_scan),
              onPressed: () => _showSerialsDialog(context, ref, item),
            ),
        ],
      ),
      onPressed: () => _showInventoryDetailDialog(context, ref, item),
    );
  }

  void _showSerialsDialog(BuildContext context, WidgetRef ref, InventoryWithProduct item) {
    showDialog(
      context: context,
      builder: (context) => _ProductSerialsDialog(productId: item.product.id, productName: item.product.name),
    );
  }

  void _showInventoryDetailDialog(BuildContext context, WidgetRef ref, InventoryWithProduct item) {
    showDialog(
      context: context,
      builder: (context) => _InventoryDetailDialog(item: item),
    );
  }
}

// Serial Numbers Tab
class _SerialNumbersTab extends ConsumerStatefulWidget {
  const _SerialNumbersTab();

  @override
  ConsumerState<_SerialNumbersTab> createState() => _SerialNumbersTabState();
}

class _SerialNumbersTabState extends ConsumerState<_SerialNumbersTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serialsAsync = _searchQuery.isNotEmpty
        ? ref.watch(serialSearchProvider(_searchQuery))
        : ref.watch(serialNumbersByStatusProvider(SerialStatus.inStock));

    return Column(
      children: [
        // Search
        Row(
          children: [
            Expanded(
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search by serial number...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(FluentIcons.search, size: 16),
                ),
                onSubmitted: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              child: const Text('Search'),
              onPressed: () {
                setState(() => _searchQuery = _searchController.text);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Serial numbers list
        Expanded(
          child: serialsAsync.when(
            data: (serials) {
              if (serials.isEmpty) {
                return Center(
                  child: Text(_searchQuery.isEmpty
                      ? 'No serial numbers in stock'
                      : 'No serial numbers found matching "$_searchQuery"'),
                );
              }

              return Card(
                child: ListView.builder(
                  itemCount: serials.length,
                  itemBuilder: (context, index) {
                    final serial = serials[index];
                    return _buildSerialTile(context, ref, serial);
                  },
                ),
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildSerialTile(BuildContext context, WidgetRef ref, SerialNumber serial) {
    final status = SerialStatusExtension.fromString(serial.status);

    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getStatusColor(status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          FluentIcons.generic_scan,
          color: _getStatusColor(status),
        ),
      ),
      title: Text(
        serial.serialNumber,
        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Cost: ${Formatters.currency(serial.unitCost)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status.displayName,
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(FluentIcons.history),
            onPressed: () => _showSerialHistoryDialog(context, ref, serial),
          ),
        ],
      ),
      onPressed: () => _showSerialHistoryDialog(context, ref, serial),
    );
  }

  Color _getStatusColor(SerialStatus status) {
    switch (status) {
      case SerialStatus.inStock:
        return AppTheme.successColor;
      case SerialStatus.sold:
        return Colors.blue;
      case SerialStatus.inRepair:
        return AppTheme.warningColor;
      case SerialStatus.returned:
        return Colors.orange;
      case SerialStatus.defective:
        return AppTheme.errorColor;
      case SerialStatus.disposed:
        return Colors.grey[100]!;
    }
  }

  void _showSerialHistoryDialog(BuildContext context, WidgetRef ref, SerialNumber serial) {
    showDialog(
      context: context,
      builder: (context) => _SerialHistoryDialog(serial: serial),
    );
  }
}

// Low Stock Tab
class _LowStockTab extends ConsumerWidget {
  const _LowStockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockProvider);

    return lowStockAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.completed_solid, size: 48, color: AppTheme.successColor),
                const SizedBox(height: 16),
                const Text('All stock levels are healthy!'),
              ],
            ),
          );
        }

        return Card(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile.selectable(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(FluentIcons.warning, color: AppTheme.errorColor),
                ),
                title: Text(item.product.name),
                subtitle: Text('Code: ${item.product.code}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Current: ${item.quantityOnHand}',
                      style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Reorder Level: ${item.product.reorderLevel}',
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// Product Serials Dialog
class _ProductSerialsDialog extends ConsumerWidget {
  final String productId;
  final String productName;

  const _ProductSerialsDialog({required this.productId, required this.productName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serialsAsync = ref.watch(productSerialNumbersProvider(productId));

    return ContentDialog(
      title: Text('Serial Numbers - $productName'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
      content: serialsAsync.when(
        data: (serials) {
          if (serials.isEmpty) {
            return const Center(child: Text('No serial numbers for this product'));
          }

          return ListView.builder(
            itemCount: serials.length,
            itemBuilder: (context, index) {
              final serial = serials[index];
              final status = SerialStatusExtension.fromString(serial.status);

              return ListTile(
                title: Text(
                  serial.serialNumber,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                subtitle: Text(Formatters.currency(serial.unitCost)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              );
            },
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
      ],
    );
  }

  Color _getStatusColor(SerialStatus status) {
    switch (status) {
      case SerialStatus.inStock:
        return AppTheme.successColor;
      case SerialStatus.sold:
        return Colors.blue;
      case SerialStatus.inRepair:
        return AppTheme.warningColor;
      case SerialStatus.returned:
        return Colors.orange;
      case SerialStatus.defective:
        return AppTheme.errorColor;
      case SerialStatus.disposed:
        return Colors.grey[100]!;
    }
  }
}

// Inventory Detail Dialog
class _InventoryDetailDialog extends StatelessWidget {
  final InventoryWithProduct item;

  const _InventoryDetailDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(item.product.name),
      constraints: const BoxConstraints(maxWidth: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('Product Code', item.product.code),
          _buildRow('Quantity on Hand', item.quantityOnHand.toString()),
          _buildRow('Reserved Quantity', item.inventory.reservedQuantity.toString()),
          _buildRow('Available Quantity', item.availableQuantity.toString()),
          _buildRow('Weighted Avg Cost', Formatters.currency(item.wac)),
          _buildRow('Total Value', Formatters.currency(item.totalCost)),
          _buildRow('Reorder Level', item.product.reorderLevel.toString()),
          if (item.product.requiresSerial)
            _buildRow('Serialized', 'Yes'),
        ],
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Serial History Dialog
class _SerialHistoryDialog extends ConsumerWidget {
  final SerialNumber serial;

  const _SerialHistoryDialog({required this.serial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(serialHistoryProvider(serial.id));

    return ContentDialog(
      title: Text('Serial History: ${serial.serialNumber}'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
      content: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return const Center(child: Text('No history available'));
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              final fromStatus = entry.fromStatus.isNotEmpty
                  ? SerialStatusExtension.fromString(entry.fromStatus)
                  : null;
              final toStatus = SerialStatusExtension.fromString(entry.toStatus);

              return ListTile(
                leading: const Icon(FluentIcons.history),
                title: Text(
                  fromStatus != null
                      ? '${fromStatus.displayName} → ${toStatus.displayName}'
                      : 'Created (${toStatus.displayName})',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Formatters.dateTime(entry.createdAt)),
                    if (entry.referenceType != null)
                      Text('Ref: ${entry.referenceType}'),
                    if (entry.notes != null)
                      Text(entry.notes!),
                  ],
                ),
              );
            },
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
      ],
    );
  }
}
