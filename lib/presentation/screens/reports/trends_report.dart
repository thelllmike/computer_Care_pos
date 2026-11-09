import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/local/daos/sales_trends.dart';
import '../../providers/core/database_provider.dart';
import '../../providers/sales/sales_provider.dart';
import 'report_charts.dart';

class TrendsData {
  final ReportPeriod period;
  final List<TrendPoint> points;
  final double prevRevenue;
  final double prevProfit;
  final int prevCount;
  final List<ProductTotal> topProducts;
  final List<MethodTotal> paymentMix;

  TrendsData(this.period, this.points, this.prevRevenue, this.prevProfit, this.prevCount,
      this.topProducts, this.paymentMix);

  double get revenue => points.fold(0, (a, p) => a + p.revenue);
  double get profit => points.fold(0, (a, p) => a + p.profit);
  int get count => points.fold(0, (a, p) => a + p.count);
  double get avgSale => count == 0 ? 0 : revenue / count;
  double get prevAvgSale => prevCount == 0 ? 0 : prevRevenue / prevCount;
}

final trendsProvider = FutureProvider.family<TrendsData, String>((ref, key) async {
  ref.watch(salesRefreshProvider);
  final dao = ref.watch(databaseProvider).salesDao;
  final period = ReportPeriod.of(key);
  final prev = period.previous();

  final points = await dao.revenueTrend(period.start, period.end, monthly: period.monthly);
  final prevPoints = await dao.revenueTrend(prev.start, prev.end, monthly: period.monthly);
  return TrendsData(
    period,
    points,
    prevPoints.fold(0, (a, p) => a + p.revenue),
    prevPoints.fold(0, (a, p) => a + p.profit),
    prevPoints.fold(0, (a, p) => a + p.count),
    await dao.topProducts(period.start, period.end),
    await dao.paymentMix(period.start, period.end),
  );
});

String _methodName(String code) {
  switch (code.toUpperCase()) {
    case 'CASH':
      return 'Cash';
    case 'CARD':
      return 'Card';
    case 'BANK_TRANSFER':
    case 'BANK':
      return 'Bank transfer';
    case 'CHEQUE':
      return 'Cheque';
    case 'CREDIT (UNPAID)':
      return 'Credit (unpaid)';
    default:
      return code;
  }
}

class TrendsReport extends ConsumerStatefulWidget {
  const TrendsReport({super.key});

  @override
  ConsumerState<TrendsReport> createState() => _TrendsReportState();
}

class _TrendsReportState extends ConsumerState<TrendsReport> {
  String _period = '30d';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trendsProvider(_period));
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
              onPressed: () => ref.read(salesRefreshProvider.notifier).state++,
              child: const Row(children: [Icon(FluentIcons.refresh, size: 14), SizedBox(width: 6), Text('Refresh')]),
            ),
          ]),
          const SizedBox(height: 20),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: ProgressRing())),
            error: (e, _) => Text('Error: $e'),
            data: (d) {
              final labels = d.points.map((p) => axisLabel(p.bucket, d.period.monthly)).toList();
              final tips = d.points.map((p) => tooltipLabel(p.bucket, d.period.monthly)).toList();
              final unit = d.period.monthly ? 'month' : 'day';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: KpiTile(title: 'Revenue', value: Formatters.currency(d.revenue), current: d.revenue, previous: d.prevRevenue)),
                    const SizedBox(width: 12),
                    Expanded(child: KpiTile(title: 'Gross profit', value: Formatters.currency(d.profit), current: d.profit, previous: d.prevProfit)),
                    const SizedBox(width: 12),
                    Expanded(child: KpiTile(title: 'Sales', value: '${d.count}', current: d.count.toDouble(), previous: d.prevCount.toDouble())),
                    const SizedBox(width: 12),
                    Expanded(child: KpiTile(title: 'Average sale', value: Formatters.currency(d.avgSale), current: d.avgSale, previous: d.prevAvgSale)),
                  ])),
                  const SizedBox(height: 16),
                  ChartCard(
                    title: 'Revenue and profit',
                    subtitle: 'Per $unit · ${d.period.label.toLowerCase()} · returned sales excluded',
                    child: TrendLineChart(
                      labels: labels,
                      tooltipLabels: tips,
                      series: [
                        ChartSeries('Revenue', d.points.map((p) => p.revenue).toList(), c.series1),
                        ChartSeries('Profit', d.points.map((p) => p.profit).toList(), c.series2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ChartCard(
                          title: 'Top products',
                          subtitle: 'By revenue',
                          child: HBarList(
                            color: c.series1,
                            items: d.topProducts
                                .map((p) => HBarItem(p.name, p.revenue, Formatters.currency(p.revenue),
                                    subLabel: '${p.quantity} sold'))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ChartCard(
                          title: 'How customers paid',
                          subtitle: 'Amount received by method',
                          child: HBarList(
                            color: c.series1,
                            items: d.paymentMix
                                .map((m) => HBarItem(_methodName(m.method), m.amount, Formatters.currency(m.amount)))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ChartCard(
                    title: 'Sales count',
                    subtitle: 'Number of sales per $unit',
                    child: TrendLineChart(
                      height: 180,
                      money: false,
                      labels: labels,
                      tooltipLabels: tips,
                      series: [ChartSeries('Sales', d.points.map((p) => p.count.toDouble()).toList(), c.series3)],
                    ),
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
