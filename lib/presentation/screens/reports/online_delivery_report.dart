import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/online_order_model.dart';
import '../../providers/online_delivery/online_delivery_provider.dart';
import '../online_delivery/widgets/order_status_chip.dart';
import 'report_charts.dart';

/// Orders that have been dispatched count as sales.
const _completed = {'SHIPPED', 'DELIVERED'};
const _open = {'PENDING', 'CONFIRMED', 'PACKED'};
const _statusOrder = ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED'];
const _statusNames = {
  'PENDING': 'Pending',
  'CONFIRMED': 'Confirmed',
  'PACKED': 'Packed',
  'SHIPPED': 'Shipped',
  'DELIVERED': 'Delivered',
  'CANCELLED': 'Cancelled',
  'RETURNED': 'Returned',
};
// Same status colours as the order status chips (always shown with the label).
const _statusColors = {
  'PENDING': Color(0xFFFF8C00),
  'CONFIRMED': Color(0xFF0078D4),
  'PACKED': Color(0xFF8764B8),
  'SHIPPED': Color(0xFF4169E1),
  'DELIVERED': Color(0xFF107C10),
  'CANCELLED': Color(0xFFD13438),
  'RETURNED': Color(0xFF8B4513),
};

class OnlineReportData {
  final ReportPeriod period;
  final List<OnlineOrderModel> orders; // in period
  final List<OnlineOrderModel> prevOrders; // previous period
  OnlineReportData(this.period, this.orders, this.prevOrders);

  static double salesOf(Iterable<OnlineOrderModel> o) =>
      o.where((x) => _completed.contains(x.deliveryStatus)).fold(0.0, (a, x) => a + x.totalAmount);

  List<OnlineOrderModel> get completed => orders.where((o) => _completed.contains(o.deliveryStatus)).toList();
  double get sales => salesOf(orders);
  double get prevSales => salesOf(prevOrders);
  double get profit => completed.fold(0.0, (a, o) => a + o.grossProfit);
  double get deliveryFees => completed.fold(0.0, (a, o) => a + o.deliveryFee);
  double get openValue =>
      orders.where((o) => _open.contains(o.deliveryStatus)).fold(0.0, (a, o) => a + o.totalAmount);
  int get openCount => orders.where((o) => _open.contains(o.deliveryStatus)).length;
  int get lostCount => orders.where((o) => o.deliveryStatus == 'CANCELLED' || o.deliveryStatus == 'RETURNED').length;
  int get prevCompletedCount => prevOrders.where((o) => _completed.contains(o.deliveryStatus)).length;
}

final onlineReportProvider = FutureProvider.family<OnlineReportData, String>((ref, key) async {
  ref.watch(onlineOrdersRefreshProvider);
  final service = ref.watch(onlineDeliveryServiceProvider);
  final period = ReportPeriod.of(key);
  final prev = period.previous();
  final all = await service.fetchOrders();
  bool inRange(OnlineOrderModel o, ReportPeriod p) {
    final d = o.orderDate.toLocal();
    return !d.isBefore(p.start) && !d.isAfter(p.end);
  }

  return OnlineReportData(
    period,
    all.where((o) => inRange(o, period)).toList()..sort((a, b) => b.orderDate.compareTo(a.orderDate)),
    all.where((o) => inRange(o, prev)).toList(),
  );
});

class OnlineDeliveryReport extends ConsumerStatefulWidget {
  const OnlineDeliveryReport({super.key});

  @override
  ConsumerState<OnlineDeliveryReport> createState() => _OnlineDeliveryReportState();
}

class _OnlineDeliveryReportState extends ConsumerState<OnlineDeliveryReport> {
  String _period = '30d';

  List<DateTime> _buckets(ReportPeriod p) {
    final out = <DateTime>[];
    var cur = p.monthly ? DateTime(p.start.year, p.start.month) : DateTime(p.start.year, p.start.month, p.start.day);
    while (!cur.isAfter(p.end)) {
      out.add(cur);
      cur = p.monthly ? DateTime(cur.year, cur.month + 1) : DateTime(cur.year, cur.month, cur.day + 1);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(onlineReportProvider(_period));
    final c = ChartColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            PeriodPicker(value: _period, onChanged: (v) => setState(() => _period = v)),
            const SizedBox(width: 12),
            Button(
              onPressed: () => ref.read(onlineOrdersRefreshProvider.notifier).state++,
              child: const Row(children: [Icon(FluentIcons.refresh, size: 14), SizedBox(width: 6), Text('Refresh')]),
            ),
          ]),
          const SizedBox(height: 20),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: ProgressRing())),
            error: (e, _) => InfoBar(
              title: const Text('Could not load online orders'),
              content: Text('$e\nOnline orders are read from the cloud, so check your internet connection.'),
              severity: InfoBarSeverity.error,
              isLong: true,
            ),
            data: (d) {
              final p = d.period;
              final buckets = _buckets(p);
              final index = {for (var i = 0; i < buckets.length; i++) buckets[i]: i};
              final salesPerBucket = List<double>.filled(buckets.length, 0);
              final ordersPerBucket = List<double>.filled(buckets.length, 0);
              for (final o in d.orders) {
                final ld = o.orderDate.toLocal();
                final b = p.monthly ? DateTime(ld.year, ld.month) : DateTime(ld.year, ld.month, ld.day);
                final i = index[b];
                if (i == null) continue;
                ordersPerBucket[i] += 1;
                if (_completed.contains(o.deliveryStatus)) salesPerBucket[i] += o.totalAmount;
              }
              final labels = buckets.map((b) => axisLabel(b, p.monthly)).toList();
              final tips = buckets.map((b) => tooltipLabel(b, p.monthly)).toList();
              final unit = p.monthly ? 'month' : 'day';

              final statusCounts = {for (final s in _statusOrder) s: 0};
              for (final o in d.orders) {
                statusCounts[o.deliveryStatus] = (statusCounts[o.deliveryStatus] ?? 0) + 1;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: KpiTile(title: 'Online sales (shipped + delivered)', value: Formatters.currency(d.sales), current: d.sales, previous: d.prevSales)),
                    const SizedBox(width: 12),
                    Expanded(child: KpiTile(title: 'Completed orders', value: '${d.completed.length}', current: d.completed.length.toDouble(), previous: d.prevCompletedCount.toDouble())),
                    const SizedBox(width: 12),
                    Expanded(child: KpiTile(title: 'Gross profit', value: Formatters.currency(d.profit), note: 'Delivery fees: ${Formatters.currency(d.deliveryFees)}')),
                    const SizedBox(width: 12),
                    Expanded(child: KpiTile(title: 'Open orders', value: '${d.openCount}', note: '${Formatters.currency(d.openValue)} not yet shipped')),
                  ])),
                  const SizedBox(height: 16),
                  ChartCard(
                    title: 'Online sales trend',
                    subtitle: 'Value of shipped + delivered orders per $unit (by order date)',
                    child: TrendLineChart(
                      labels: labels,
                      tooltipLabels: tips,
                      series: [ChartSeries('Online sales', salesPerBucket, c.series1)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ChartCard(
                          title: 'Orders by status',
                          subtitle: '${d.orders.length} orders · ${d.lostCount} cancelled or returned',
                          child: HBarList(
                            color: c.series1,
                            items: [
                              for (final s in _statusOrder)
                                if ((statusCounts[s] ?? 0) > 0)
                                  HBarItem(_statusNames[s]!, statusCounts[s]!.toDouble(), '${statusCounts[s]}',
                                      color: _statusColors[s]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ChartCard(
                          title: 'Orders received',
                          subtitle: 'New orders per $unit',
                          child: TrendLineChart(
                            height: 200,
                            money: false,
                            labels: labels,
                            tooltipLabels: tips,
                            series: [ChartSeries('Orders', ordersPerBucket, c.series3)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ChartCard(
                    title: 'Orders in this period',
                    subtitle: d.orders.isEmpty ? null : 'Newest first',
                    child: d.orders.isEmpty
                        ? Text('No online orders in this period.', style: TextStyle(color: c.axisText))
                        : _OrdersTable(orders: d.orders),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  final List<OnlineOrderModel> orders;
  const _OrdersTable({required this.orders});

  @override
  Widget build(BuildContext context) {
    final c = ChartColors.of(context);
    TextStyle head = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.axisText);
    TextStyle cell = TextStyle(fontSize: 12, color: c.primaryText);
    Widget row(List<Widget> cells, {bool header = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.grid))),
          child: Row(children: [
            Expanded(flex: 2, child: cells[0]),
            Expanded(flex: 2, child: cells[1]),
            Expanded(flex: 3, child: cells[2]),
            Expanded(flex: 3, child: cells[3]),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: cells[4])),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: cells[5]),
          ]),
        );
    return Column(children: [
      row([
        Text('Order #', style: head),
        Text('Date', style: head),
        Text('Customer', style: head),
        Text('Tracking', style: head),
        Text('Total', style: head),
        Text('Status', style: head),
      ]),
      for (final o in orders)
        row([
          Text(o.orderNumber, style: cell.copyWith(fontWeight: FontWeight.w600)),
          Text(Formatters.date(o.orderDate.toLocal()), style: cell),
          Text(o.displayCustomerName, style: cell, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(o.trackingNumber ?? '—', style: cell, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(Formatters.currency(o.totalAmount), style: cell),
          Align(alignment: Alignment.centerLeft, child: OrderStatusChip(status: o.deliveryStatus)),
        ]),
    ]);
  }
}
