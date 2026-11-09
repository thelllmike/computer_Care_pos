import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Chart palette: validated categorical slots (light / dark steps), plus
// recessive grid and text tokens. Series colours follow the entity, never rank.
// ---------------------------------------------------------------------------
class ChartColors {
  final bool dark;
  const ChartColors._(this.dark);
  factory ChartColors.of(BuildContext context) => ChartColors._(AppTheme.isDark(context));

  Color get series1 => dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6); // blue
  Color get series2 => dark ? const Color(0xFFD95926) : const Color(0xFFEB6834); // orange
  Color get series3 => dark ? const Color(0xFF199E70) : const Color(0xFF1BAF7A); // aqua
  Color get grid => dark ? const Color(0xFF3A3A38) : const Color(0xFFE6E5E1);
  Color get axisText => dark ? const Color(0xFFC3C2B7) : const Color(0xFF52514E);
  Color get primaryText => dark ? const Color(0xFFF0EFEC) : const Color(0xFF0B0B0B);
  Color get tooltipBg => dark ? const Color(0xFF2B2B29) : const Color(0xFFFFFFFF);
  Color get surface => dark ? const Color(0xFF2D2D2D) : Colors.white;
}

/// Short money labels for axes: 1.2K, 3.4M.
String compactMoney(double v) {
  final a = v.abs();
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(a >= 1e7 ? 0 : 1)}M';
  if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1)}K';
  return v.toStringAsFixed(0);
}

class ChartSeries {
  final String name;
  final List<double> values;
  final Color color;
  const ChartSeries(this.name, this.values, this.color);
}

/// Line chart over time (one y-axis) with a hover tooltip and a legend
/// when there is more than one series.
class TrendLineChart extends StatelessWidget {
  final List<String> labels; // one per x position
  final List<String> tooltipLabels;
  final List<ChartSeries> series;
  final double height;
  final bool money; // false = plain counts

  const TrendLineChart({
    super.key,
    required this.labels,
    required this.tooltipLabels,
    required this.series,
    this.height = 260,
    this.money = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = ChartColors.of(context);
    final all = series.expand((s) => s.values);
    final maxV = all.isEmpty ? 0.0 : all.reduce(math.max);
    final minV = all.isEmpty ? 0.0 : all.reduce(math.min);
    final top = maxV <= 0 ? 1.0 : maxV * 1.1;
    final bottom = minV < 0 ? minV * 1.1 : 0.0;
    final n = labels.length;
    final labelEvery = n <= 8 ? 1 : (n / 7).ceil();
    final showDots = n <= 31;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (series.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 16,
              children: [
                for (final s in series)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 14, height: 3, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text(s.name, style: TextStyle(fontSize: 12, color: c.axisText)),
                  ]),
              ],
            ),
          ),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(0, n - 1).toDouble(),
              minY: bottom,
              maxY: top,
              borderData: FlBorderData(
                show: true,
                border: Border(bottom: BorderSide(color: c.grid)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: c.grid, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max || value == meta.min && value != 0) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(money ? compactMoney(value) : value.toStringAsFixed(0),
                            style: TextStyle(fontSize: 11, color: c.axisText)),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (value != i.toDouble() || i < 0 || i >= n || i % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(labels[i], style: TextStyle(fontSize: 11, color: c.axisText)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (bar, indexes) => indexes
                    .map((_) => TouchedSpotIndicatorData(
                          FlLine(color: c.axisText.withValues(alpha: 0.5), strokeWidth: 1),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, _, b, __) => FlDotCirclePainter(
                                radius: 5, color: b.color ?? c.series1, strokeWidth: 2, strokeColor: c.surface),
                          ),
                        ))
                    .toList(),
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: c.tooltipBg,
                  tooltipBorder: BorderSide(color: c.grid),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) {
                    return spots.asMap().entries.map((e) {
                      final spot = e.value;
                      final s = series[spot.barIndex];
                      final head = e.key == 0 ? '${tooltipLabels[spot.x.round()]}\n' : '';
                      return LineTooltipItem(
                        head,
                        TextStyle(color: c.axisText, fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.left,
                        children: [
                          TextSpan(text: '● ', style: TextStyle(color: s.color, fontSize: 11)),
                          TextSpan(
                            text: '${s.name}: ${money ? Formatters.currency(spot.y) : spot.y.toStringAsFixed(0)}',
                            style: TextStyle(color: c.primaryText, fontSize: 12, fontWeight: FontWeight.normal),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: [for (var i = 0; i < s.values.length; i++) FlSpot(i.toDouble(), s.values[i])],
                    color: s.color,
                    barWidth: 2,
                    isCurved: false,
                    dotData: FlDotData(
                      show: showDots,
                      getDotPainter: (spot, _, bar, __) => FlDotCirclePainter(
                          radius: 3, color: s.color, strokeWidth: 1.5, strokeColor: c.surface),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class HBarItem {
  final String label;
  final double value;
  final String valueLabel;
  final String? subLabel;
  final Color? color; // only for status bars (paired with the text label)
  const HBarItem(this.label, this.value, this.valueLabel, {this.subLabel, this.color});
}

/// Horizontal bar list: label left, thin bar, value right. Hover shows a tooltip.
class HBarList extends StatelessWidget {
  final List<HBarItem> items;
  final Color color;
  final String emptyText;

  const HBarList({super.key, required this.items, required this.color, this.emptyText = 'No data for this period'});

  @override
  Widget build(BuildContext context) {
    final c = ChartColors.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(emptyText, style: TextStyle(color: c.axisText))),
      );
    }
    final maxV = items.map((i) => i.value).fold<double>(0, math.max);
    return Column(
      children: [
        for (final item in items)
          Tooltip(
            message: '${item.label}: ${item.valueLabel}${item.subLabel != null ? ' · ${item.subLabel}' : ''}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(item.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.primaryText)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final frac = maxV <= 0 ? 0.0 : (item.value / maxV).clamp(0.0, 1.0);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 12,
                          width: math.max(frac * box.maxWidth, item.value > 0 ? 3 : 0),
                          decoration: BoxDecoration(
                            color: item.color ?? color,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: Text(item.valueLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primaryText)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// KPI tile with change vs the previous period (arrow + text, not colour alone).
class KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final double? current;
  final double? previous;
  final String? note;

  const KpiTile({super.key, required this.title, required this.value, this.current, this.previous, this.note});

  @override
  Widget build(BuildContext context) {
    final c = ChartColors.of(context);
    Widget? delta;
    if (current != null && previous != null) {
      if (previous == 0) {
        delta = Text(current == 0 ? 'No change' : 'New vs previous period',
            style: TextStyle(fontSize: 11, color: c.axisText));
      } else {
        final pct = (current! - previous!) / previous!.abs() * 100;
        final up = pct >= 0;
        final color = up ? AppTheme.successColor : AppTheme.errorColor;
        delta = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(up ? FluentIcons.up : FluentIcons.down, size: 10, color: color),
          const SizedBox(width: 4),
          Text('${up ? '+' : ''}${pct.toStringAsFixed(1)}% vs previous',
              style: TextStyle(fontSize: 11, color: c.axisText)),
        ]);
      }
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: c.axisText)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.primaryText)),
          const SizedBox(height: 4),
          if (delta != null) delta,
          if (note != null) Text(note!, style: TextStyle(fontSize: 11, color: c.axisText)),
        ],
      ),
    );
  }
}

/// Titled card wrapper for a chart.
class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const ChartCard({super.key, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = ChartColors.of(context);
    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.primaryText)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: c.axisText)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Report periods
// ---------------------------------------------------------------------------
class ReportPeriod {
  final String key;
  final String label;
  final DateTime start;
  final DateTime end;
  final bool monthly;
  const ReportPeriod(this.key, this.label, this.start, this.end, this.monthly);

  /// Same-length period immediately before this one.
  ReportPeriod previous() {
    if (monthly) {
      final months = (end.year - start.year) * 12 + end.month - start.month + 1;
      return ReportPeriod(key, label, DateTime(start.year, start.month - months, 1),
          DateTime(start.year, start.month, 0, 23, 59, 59), true);
    }
    final days = DateTime(end.year, end.month, end.day).difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    return ReportPeriod(key, label, start.subtract(Duration(days: days)),
        DateTime(start.year, start.month, start.day).subtract(const Duration(seconds: 1)), false);
  }

  static const keys = ['7d', '30d', '90d', '12m'];

  static ReportPeriod of(String key) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    DateTime daysBack(int n) => DateTime(now.year, now.month, now.day - (n - 1));
    switch (key) {
      case '7d':
        return ReportPeriod(key, 'Last 7 days', daysBack(7), endOfToday, false);
      case '90d':
        return ReportPeriod(key, 'Last 90 days', daysBack(90), endOfToday, false);
      case '12m':
        return ReportPeriod(key, 'Last 12 months', DateTime(now.year, now.month - 11, 1), endOfToday, true);
      case '30d':
      default:
        return ReportPeriod('30d', 'Last 30 days', daysBack(30), endOfToday, false);
    }
  }
}

const _kShortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String axisLabel(DateTime d, bool monthly) =>
    monthly ? _kShortMonths[d.month - 1] : '${d.day} ${_kShortMonths[d.month - 1]}';

String tooltipLabel(DateTime d, bool monthly) =>
    monthly ? '${_kShortMonths[d.month - 1]} ${d.year}' : Formatters.date(d);

/// Period picker shared by the chart reports.
class PeriodPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const PeriodPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ComboBox<String>(
      value: value,
      items: [for (final k in ReportPeriod.keys) ComboBoxItem(value: k, child: Text(ReportPeriod.of(k).label))],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}
