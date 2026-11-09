import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/models/online_order_model.dart';
import '../../../providers/online_delivery/online_delivery_provider.dart';
import '../widgets/order_status_chip.dart';
import 'assign_serials_dialog.dart';

class OnlineOrderDetailDialog extends ConsumerWidget {
  final String orderId;

  const OnlineOrderDetailDialog({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(onlineOrderDetailProvider(orderId));
    final actionState = ref.watch(onlineOrderActionProvider);

    ref.listen<OnlineOrderActionState>(onlineOrderActionProvider,
        (prev, next) {
      if (next.isSuccess && !(prev?.isSuccess ?? false)) {
        displayInfoBar(context, builder: (ctx, close) {
          final data = next.resultData;
          String msg = 'Order updated successfully.';
          if (data != null && data['invoice_number'] != null) {
            msg = 'Order shipped. Invoice: ${data['invoice_number']}';
          }
          return InfoBar(
            title: const Text('Success'),
            content: Text(msg),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
        ref.read(onlineOrderActionProvider.notifier).reset();
      }
      if (next.error != null && prev?.error == null) {
        displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(next.error!),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
        ref.read(onlineOrderActionProvider.notifier).reset();
      }
    });

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 720),
      title: orderAsync.when(
        data: (o) => o != null
            ? Row(
                children: [
                  Expanded(child: Text('Order ${o.orderNumber}')),
                  OrderStatusChip(status: o.deliveryStatus),
                ],
              )
            : const Text('Order Detail'),
        loading: () => const Text('Loading...'),
        error: (_, __) => const Text('Order Detail'),
      ),
      content: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Customer & Address ─────────────────────────
                _SectionCard(
                  title: 'Customer Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                          label: 'Name',
                          value: order.displayCustomerName),
                      if (order.customerPhone != null)
                        _DetailRow(
                            label: 'Phone',
                            value: order.customerPhone!),
                      _DetailRow(
                          label: 'Address',
                          value: order.customerAddress),
                      _DetailRow(
                          label: 'Order Date',
                          value:
                              Formatters.dateTime(order.orderDate.toLocal())),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Items ──────────────────────────────────────
                _SectionCard(
                  title: 'Items',
                  child: order.items.isEmpty
                      ? const Text('No items.')
                      : Column(
                          children: [
                            // Header
                            const Row(
                              children: [
                                Expanded(
                                    flex: 4,
                                    child: Text('Product',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600))),
                                Expanded(
                                    flex: 1,
                                    child: Text('Qty',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Unit Price',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Total',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Serials',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600))),
                              ],
                            ),
                            const Divider(),
                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.productName ??
                                                item.productId),
                                            if (item.requiresSerial)
                                              Text(
                                                'Requires Serial',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: const Color(
                                                          0xFF8764B8)
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                          flex: 1,
                                          child:
                                              Text('${item.quantity}')),
                                      Expanded(
                                        flex: 2,
                                        child: Text(Formatters.currency(
                                            item.unitPrice)),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          Formatters.currency(
                                              item.totalPrice),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: item.requiresSerial
                                            ? _SerialBadge(
                                                assigned:
                                                    item.serials.length,
                                                required: item.quantity,
                                                canAssign: _canAssignSerials(
                                                    order.deliveryStatus),
                                                onAssign: () =>
                                                    _showAssignSerials(
                                                        context,
                                                        order,
                                                        item),
                                              )
                                            : const Text('—'),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                ),
                const SizedBox(height: 12),

                // ── Financials ─────────────────────────────────
                _SectionCard(
                  title: 'Financials',
                  child: Column(
                    children: [
                      _DetailRow(
                          label: 'Subtotal',
                          value: Formatters.currency(order.subtotal)),
                      if (order.deliveryFee > 0)
                        _DetailRow(
                            label: 'Delivery Fee',
                            value:
                                Formatters.currency(order.deliveryFee)),
                      if (order.discountAmount > 0)
                        _DetailRow(
                            label: 'Discount',
                            value: Formatters.currency(
                                order.discountAmount)),
                      _DetailRow(
                          label: 'Total',
                          value: Formatters.currency(order.totalAmount),
                          bold: true),
                      _DetailRow(
                          label: 'Payment',
                          value: order.paymentMethod +
                              (order.isPrepaid ? ' (Prepaid)' : '')),
                    ],
                  ),
                ),

                // ── Shipping info ──────────────────────────────
                if (order.trackingNumber != null ||
                    order.shippedAt != null ||
                    order.deliveredAt != null ||
                    order.linkedSaleId != null) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Shipping',
                    child: Column(
                      children: [
                        if (order.trackingNumber != null)
                          _DetailRow(
                              label: 'Tracking',
                              value: order.trackingNumber!),
                        if (order.shippedAt != null)
                          _DetailRow(
                              label: 'Shipped At',
                              value: Formatters.dateTime(
                                  order.shippedAt!.toLocal())),
                        if (order.deliveredAt != null)
                          _DetailRow(
                              label: 'Delivered At',
                              value: Formatters.dateTime(
                                  order.deliveredAt!.toLocal())),
                        if (order.linkedSaleId != null)
                          _DetailRow(
                              label: 'Linked Sale',
                              value: order.linkedSaleId!),
                      ],
                    ),
                  ),
                ],

                if (order.notes != null) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Notes',
                    child: Text(order.notes!),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) =>
            Center(child: Text('Failed to load order: $e')),
      ),
      actions: [
        Button(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ...orderAsync.when(
          data: (order) =>
              order != null ? _buildActionButtons(context, ref, order, actionState) : [],
          loading: () => [],
          error: (_, __) => [],
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    OnlineOrderModel order,
    OnlineOrderActionState actionState,
  ) {
    final status = order.deliveryStatus;
    final isLoading = actionState.isLoading;

    Widget loadingIndicator() => const SizedBox(
        width: 16, height: 16, child: ProgressRing(strokeWidth: 2));

    final buttons = <Widget>[];

    switch (status) {
      case 'PENDING':
        buttons.add(FilledButton(
          onPressed: isLoading
              ? null
              : () => ref
                  .read(onlineOrderActionProvider.notifier)
                  .updateStatus(orderId, 'CONFIRMED'),
          child: isLoading ? loadingIndicator() : const Text('Confirm Order'),
        ));
        buttons.add(Button(
          style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                  const Color(0xFFD13438).withValues(alpha: 0.1))),
          onPressed: isLoading
              ? null
              : () => _confirmCancel(context, ref),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFFD13438))),
        ));
        break;

      case 'CONFIRMED':
        buttons.add(FilledButton(
          onPressed: isLoading
              ? null
              : () => ref
                  .read(onlineOrderActionProvider.notifier)
                  .updateStatus(orderId, 'PACKED'),
          child: isLoading
              ? loadingIndicator()
              : const Text('Mark as Packed'),
        ));
        buttons.add(Button(
          style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                  const Color(0xFFD13438).withValues(alpha: 0.1))),
          onPressed: isLoading
              ? null
              : () => _confirmCancel(context, ref),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFFD13438))),
        ));
        break;

      case 'PACKED':
        final canShip = _canMarkShipped(order);
        buttons.add(FilledButton(
          onPressed: (isLoading || !canShip)
              ? null
              : () => ref
                  .read(onlineOrderActionProvider.notifier)
                  .markShipped(orderId),
          child: isLoading
              ? loadingIndicator()
              : const Text('Mark as Shipped'),
        ));
        if (!canShip) {
          buttons.add(const Tooltip(
            message: 'Assign serials to all serialized items first',
            child: Icon(FluentIcons.info,
                size: 16, color: Color(0xFFFF8C00)),
          ));
        }
        buttons.add(Button(
          style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                  const Color(0xFFD13438).withValues(alpha: 0.1))),
          onPressed: isLoading
              ? null
              : () => _confirmCancel(context, ref),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFFD13438))),
        ));
        break;

      case 'SHIPPED':
        buttons.add(FilledButton(
          onPressed: isLoading
              ? null
              : () => ref
                  .read(onlineOrderActionProvider.notifier)
                  .markDelivered(orderId),
          child: isLoading
              ? loadingIndicator()
              : const Text('Mark as Delivered'),
        ));
        break;
    }

    return buttons;
  }

  bool _canAssignSerials(String status) =>
      status == 'PENDING' ||
      status == 'CONFIRMED' ||
      status == 'PACKED';

  bool _canMarkShipped(OnlineOrderModel order) {
    for (final item in order.items) {
      if (item.requiresSerial && item.serials.length < item.quantity) {
        return false;
      }
    }
    return true;
  }

  void _showAssignSerials(
    BuildContext context,
    OnlineOrderModel order,
    OnlineOrderItemModel item,
  ) {
    showDialog(
      context: context,
      builder: (context) => AssignSerialsDialog(
        order: order,
        item: item,
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Cancel Order'),
        content: const Text(
            'Are you sure you want to cancel this order?'),
        actions: [
          Button(
            child: const Text('No'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                    const Color(0xFFD13438))),
            child: const Text('Yes, Cancel'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref
          .read(onlineOrderActionProvider.notifier)
          .updateStatus(orderId, 'CANCELLED');
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[120], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SerialBadge extends StatelessWidget {
  final int assigned;
  final int required;
  final bool canAssign;
  final VoidCallback onAssign;

  const _SerialBadge({
    required this.assigned,
    required this.required,
    required this.canAssign,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = assigned >= required;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isFull
                ? const Color(0xFF107C10).withValues(alpha: 0.15)
                : const Color(0xFFFF8C00).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$assigned/$required',
            style: TextStyle(
              fontSize: 11,
              color: isFull
                  ? const Color(0xFF107C10)
                  : const Color(0xFFFF8C00),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (canAssign) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(FluentIcons.edit, size: 12),
            onPressed: onAssign,
          ),
        ],
      ],
    );
  }
}
