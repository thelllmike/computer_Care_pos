import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/online_order_model.dart';
import '../../providers/online_delivery/online_delivery_provider.dart';
import 'dialogs/create_online_order_dialog.dart';
import 'dialogs/online_order_detail_dialog.dart';
import 'widgets/order_status_chip.dart';

class OnlineOrdersScreen extends ConsumerWidget {
  const OnlineOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(onlineOrdersProvider);
    final statusFilter = ref.watch(onlineOrderStatusFilterProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Online Delivery'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Order'),
              onPressed: () => _showCreateDialog(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: () =>
                  ref.read(onlineOrdersRefreshProvider.notifier).state++,
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter bar
            _FilterBar(
              selectedStatus: statusFilter,
              onStatusChanged: (s) => ref
                  .read(onlineOrderStatusFilterProvider.notifier)
                  .state = s,
              onSearchChanged: (q) => ref
                  .read(onlineOrderSearchQueryProvider.notifier)
                  .state = q,
            ),
            const SizedBox(height: 16),

            // Orders list
            Expanded(
              child: ordersAsync.when(
                data: (orders) => orders.isEmpty
                    ? _EmptyState(
                        onCreateTap: () => _showCreateDialog(context),
                      )
                    : _OrdersTable(
                        orders: orders,
                        onRowTap: (o) =>
                            _showDetailDialog(context, o.id),
                      ),
                loading: () =>
                    const Center(child: ProgressRing()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.error, size: 48),
                      const SizedBox(height: 16),
                      Text('Failed to load orders: $e'),
                      const SizedBox(height: 16),
                      FilledButton(
                        child: const Text('Retry'),
                        onPressed: () => ref
                            .read(onlineOrdersRefreshProvider.notifier)
                            .state++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateOnlineOrderDialog(),
    );
  }

  void _showDetailDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (context) => OnlineOrderDetailDialog(orderId: orderId),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Filter bar
// ──────────────────────────────────────────────────────────────
class _FilterBar extends StatefulWidget {
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  const _FilterBar({
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(FluentIcons.filter),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search order / customer...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(FluentIcons.search, size: 14),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
            const SizedBox(width: 16),
            ComboBox<String?>(
              placeholder: const Text('All Statuses'),
              value: widget.selectedStatus,
              items: const [
                ComboBoxItem(value: null, child: Text('All Statuses')),
                ComboBoxItem(value: 'PENDING', child: Text('Pending')),
                ComboBoxItem(
                    value: 'CONFIRMED', child: Text('Confirmed')),
                ComboBoxItem(value: 'PACKED', child: Text('Packed')),
                ComboBoxItem(value: 'SHIPPED', child: Text('Shipped')),
                ComboBoxItem(
                    value: 'DELIVERED', child: Text('Delivered')),
                ComboBoxItem(
                    value: 'CANCELLED', child: Text('Cancelled')),
                ComboBoxItem(value: 'RETURNED', child: Text('Returned')),
              ],
              onChanged: widget.onStatusChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Orders table
// ──────────────────────────────────────────────────────────────
class _OrdersTable extends StatelessWidget {
  final List<OnlineOrderModel> orders;
  final ValueChanged<OnlineOrderModel> onRowTap;

  const _OrdersTable({
    required this.orders,
    required this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.3)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Order #', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Customer', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Address', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          // Data rows
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OrderRow(order: order, onTap: () => onRowTap(order));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OnlineOrderModel order;
  final VoidCallback onTap;

  const _OrderRow({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: states.isHovered
                ? FluentTheme.of(context).accentColor.withValues(alpha: 0.05)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.15)),
            ),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.displayCustomerName),
                    if (order.customerPhone != null)
                      Text(
                        order.customerPhone!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[100]),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  order.customerAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  Formatters.dateTime(order.orderDate.toLocal()),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  Formatters.currency(order.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 2,
                child: OrderStatusChip(status: order.deliveryStatus),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.delivery_truck, size: 64, color: Colors.grey[100]),
          const SizedBox(height: 16),
          Text(
            'No online orders yet',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first online delivery order.',
            style: TextStyle(color: Colors.grey[100]),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onCreateTap,
            child: const Text('Create Order'),
          ),
        ],
      ),
    );
  }
}
