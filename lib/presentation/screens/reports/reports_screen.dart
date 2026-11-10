import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/credits/credit_provider.dart';
import '../../providers/expenses/expense_provider.dart';
import '../../providers/inventory/inventory_provider.dart';
import '../../providers/losses/stock_loss_provider.dart';
import '../../providers/repairs/repair_provider.dart';
import '../../providers/sales/sales_provider.dart';
import '../../../data/local/daos/expense_dao.dart';
import '../../../data/local/daos/sales_dao.dart';
import '../../../data/local/tables/stock_losses_table.dart';
import 'online_delivery_report.dart';
import 'trends_report.dart';

// ---------------------------------------------------------------------------
// Month helpers (file-private)
// ---------------------------------------------------------------------------

const _kMonthNames = [
  '', // index 0 unused — months are 1-based
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Returns the full month name for [offset] months before the current month.
/// [offset] = 0 → current month, 1 → last month, 2 → two months ago, etc.
/// Handles year wrap-around correctly.
String _monthName(int offset) {
  final now = DateTime.now();
  int month = now.month - offset;
  while (month <= 0) {
    month += 12;
  }
  return _kMonthNames[month];
}

/// Returns a [DateRange] covering exactly one calendar month that is [offset]
/// months before the current month.  Year rollover is handled safely.
///
/// Dart's [DateTime] constructor normalises out-of-range month values, so
/// `DateTime(year, month + 1, 0)` always gives the last day of [month].
DateRange _monthOffsetRange(int offset) {
  final now = DateTime.now();
  int month = now.month - offset;
  int year = now.year;
  while (month <= 0) {
    month += 12;
    year--;
  }
  return DateRange(
    start: DateTime(year, month, 1),
    end: DateTime(year, month + 1, 0, 23, 59, 59),
  );
}

// ---------------------------------------------------------------------------

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selectedReport;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Reports'),
        commandBar: _selectedReport != null
            ? CommandBar(
                mainAxisAlignment: MainAxisAlignment.end,
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.back),
                    label: const Text('Back to Reports'),
                    onPressed: () => setState(() => _selectedReport = null),
                  ),
                ],
              )
            : null,
      ),
      content: _selectedReport == null
          ? _buildReportsList()
          : _buildReportContent(_selectedReport!),
    );
  }

  void _open(String id) => setState(() => _selectedReport = id);

  Widget _buildReportsList() {
    final trends = ref.watch(trendsProvider('30d'));
    final online = ref.watch(onlineReportProvider('30d'));
    final stock = ref.watch(inventoryStatsProvider);
    final credit = ref.watch(creditSummaryProvider);
    final repairs = ref.watch(repairSummaryProvider);
    final primary = AppTheme.primary(context);

    _Preview trendPreview(String label, double Function(TrendsData d) cur,
        double Function(TrendsData d) prev,
        {bool money = true, bool spark = false}) {
      return trends.when(
        loading: () => const _Preview.loading(),
        error: (_, __) => const _Preview.unavailable(),
        data: (d) => _Preview(
          label: label,
          value: money ? Formatters.currency(cur(d)) : cur(d).toStringAsFixed(0),
          current: cur(d),
          previous: prev(d),
          spark: spark ? d.points.map((p) => p.revenue).toList() : null,
        ),
      );
    }

    final salesCards = [
      _ReportCard(
        title: 'Trends & Charts',
        description: 'Revenue and profit trends, top products, payments',
        icon: FluentIcons.line_chart,
        tint: primary,
        preview: trendPreview('Revenue · 30 days', (d) => d.revenue, (d) => d.prevRevenue, spark: true),
        onTap: () => _open('trends'),
      ),
      _ReportCard(
        title: 'Sales Report',
        description: 'Daily, weekly, monthly sales analysis',
        icon: FluentIcons.chart,
        tint: primary,
        preview: trendPreview('Sales · 30 days', (d) => d.count.toDouble(), (d) => d.prevCount.toDouble(), money: false),
        onTap: () => _open('sales'),
      ),
      _ReportCard(
        title: 'Profit & Loss',
        description: 'Revenue, costs, and profit margins',
        icon: FluentIcons.calculator,
        tint: primary,
        preview: trendPreview('Gross profit · 30 days', (d) => d.profit, (d) => d.prevProfit),
        onTap: () => _open('profit'),
      ),
      _ReportCard(
        title: 'Online Delivery Sales',
        description: 'Online order sales, status and trends',
        icon: FluentIcons.delivery_truck,
        tint: const Color(0xFF1BAF7A),
        preview: online.when(
          loading: () => const _Preview.loading(),
          error: (_, __) => const _Preview.unavailable(note: 'Needs internet'),
          data: (d) => _Preview(
            label: 'Online sales · 30 days',
            value: Formatters.currency(d.sales),
            current: d.sales,
            previous: d.prevSales,
          ),
        ),
        onTap: () => _open('online'),
      ),
    ];

    final otherCards = [
      _ReportCard(
        title: 'Inventory Valuation',
        description: 'Stock value based on WAC',
        icon: FluentIcons.archive,
        tint: const Color(0xFFEB6834),
        preview: stock.when(
          loading: () => const _Preview.loading(),
          error: (_, __) => const _Preview.unavailable(),
          data: (s) => _Preview(
            label: 'Stock value',
            value: Formatters.currency(s.totalValue),
            note: s.lowStockCount > 0 ? '${s.lowStockCount} low on stock' : 'Stock levels OK',
            noteColor: s.lowStockCount > 0 ? AppTheme.warningColor : null,
          ),
        ),
        onTap: () => _open('inventory'),
      ),
      _ReportCard(
        title: 'Aging Report',
        description: 'Credit aging by 30/60/90+ days',
        icon: FluentIcons.calendar,
        tint: const Color(0xFFE0A030),
        preview: credit.when(
          loading: () => const _Preview.loading(),
          error: (_, __) => const _Preview.unavailable(),
          data: (c) => _Preview(
            label: 'Customers owe',
            value: Formatters.currency(c.totalOutstanding),
            note: c.overdueAmount > 0
                ? '${Formatters.currency(c.overdueAmount)} overdue'
                : 'Nothing overdue',
            noteColor: c.overdueAmount > 0 ? AppTheme.errorColor : null,
          ),
        ),
        onTap: () => _open('aging'),
      ),
      _ReportCard(
        title: 'Repair Summary',
        description: 'Repair jobs and revenue',
        icon: FluentIcons.repair,
        tint: const Color(0xFF3987E5),
        preview: repairs.when(
          loading: () => const _Preview.loading(),
          error: (_, __) => const _Preview.unavailable(),
          data: (r) => _Preview(
            label: 'Open repair jobs',
            value: '${r.activeJobs}',
            note: '${r.completedToday} completed today',
          ),
        ),
        onTap: () => _open('repairs'),
      ),
    ];

    return LayoutBuilder(builder: (context, box) {
      const gap = 16.0;
      final width = box.maxWidth - 48;
      final cols = ((width + gap) / (280 + gap)).floor().clamp(1, 4);
      final cardWidth = (width - gap * (cols - 1)) / cols;

      Widget section(String title, List<Widget> cards) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final c in cards) SizedBox(width: cardWidth, child: c)],
              ),
            ],
          );

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a report to open it. Figures on the cards are live from your data.',
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: FluentTheme.of(context).typography.caption?.color,
                  ),
            ),
            const SizedBox(height: 20),
            section('Sales & profit', salesCards),
            const SizedBox(height: 28),
            section('Stock, credit & service', otherCards),
          ],
        ),
      );
    });
  }

  Widget _buildReportContent(String reportType) {
    switch (reportType) {
      case 'trends':
        return const TrendsReport();
      case 'online':
        return const OnlineDeliveryReport();
      case 'sales':
        return const _SalesReportContent();
      case 'profit':
        return const _ProfitReportContent();
      case 'inventory':
        return const _InventoryReportContent();
      case 'aging':
        return const _AgingReportContent();
      case 'repairs':
        return const _RepairReportContent();
      default:
        return const Center(child: Text('Report not found'));
    }
  }
}

/// Live figure shown at the bottom of a report card.
class _Preview {
  final String label;
  final String value;
  final double? current;
  final double? previous;
  final List<double>? spark;
  final String? note;
  final Color? noteColor;
  final bool loading;

  const _Preview({
    required this.label,
    required this.value,
    this.current,
    this.previous,
    this.spark,
    this.note,
    this.noteColor,
  }) : loading = false;

  const _Preview.loading()
      : label = '',
        value = '',
        current = null,
        previous = null,
        spark = null,
        note = null,
        noteColor = null,
        loading = true;

  const _Preview.unavailable({String note = 'Not available'})
      : label = '',
        value = '—',
        current = null,
        previous = null,
        spark = null,
        note = note,
        noteColor = null,
        loading = false;
}

/// Clickable report tile: lifts and highlights on hover, shrinks on press,
/// keyboard focusable (Tab + Enter), shows a live figure.
class _ReportCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color tint;
  final _Preview preview;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.preview,
    required this.onTap,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final highlight = theme.accentColor.defaultBrushFor(theme.brightness);
    const duration = Duration(milliseconds: 160);

    return HoverButton(
      onPressed: widget.onTap,
      cursor: SystemMouseCursors.click,
      semanticLabel: 'Open ${widget.title}',
      builder: (context, states) {
        final hovered = states.isHovered;
        final pressed = states.isPressed;
        final focused = states.isFocused;
        final active = hovered || focused;

        return AnimatedScale(
          scale: pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, active && !pressed ? -3 : 0, 0),
            height: 200,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: active ? AppTheme.subtleFill(context) : AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? highlight : AppTheme.dividerColor(context),
                width: active ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: active ? 0.22 : 0.06),
                  blurRadius: active ? 18 : 6,
                  offset: Offset(0, active ? 8 : 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: widget.tint.withValues(alpha: active ? 0.28 : 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, size: 20, color: widget.tint),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: active ? 1 : 0,
                      duration: duration,
                      child: AnimatedSlide(
                        offset: active ? Offset.zero : const Offset(-0.6, 0),
                        duration: duration,
                        child: Icon(FluentIcons.chevron_right, size: 14, color: highlight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption,
                ),
                const Spacer(),
                Container(height: 1, color: AppTheme.dividerColor(context)),
                const SizedBox(height: 10),
                SizedBox(height: 38, child: _previewRow(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewRow(BuildContext context) {
    final theme = FluentTheme.of(context);
    final p = widget.preview;
    if (p.loading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2)),
      );
    }

    Widget? badge;
    final cur = p.current, prev = p.previous;
    if (cur != null && prev != null && prev > 0) {
      final change = (cur - prev) / prev * 100;
      final up = change >= 0;
      final color = up ? AppTheme.successColor : AppTheme.errorColor;
      badge = Tooltip(
        message: 'Compared with the 30 days before',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                p.label.isEmpty ? (p.note ?? '') : p.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption?.copyWith(fontSize: 11),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      p.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.bodyStrong?.copyWith(fontSize: 16),
                    ),
                  ),
                  if (badge != null) ...[const SizedBox(width: 8), badge],
                  if (p.label.isNotEmpty && p.note != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        p.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption?.copyWith(
                          fontSize: 11,
                          color: p.noteColor,
                          fontWeight: p.noteColor != null ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (p.spark != null && p.spark!.length > 1) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            height: 28,
            child: CustomPaint(
              painter: _SparkPainter(p.spark!, widget.tint),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tiny revenue line for the Trends card.
class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparkPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV <= 0) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxV) * (size.height - 2) - 1;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}

// ---------------------------------------------------------------------------
// Sales Report Content
// ---------------------------------------------------------------------------

class _SalesReportContent extends ConsumerStatefulWidget {
  const _SalesReportContent();

  @override
  ConsumerState<_SalesReportContent> createState() => _SalesReportContentState();
}

class _SalesReportContentState extends ConsumerState<_SalesReportContent> {
  String _period = 'today';

  DateRange _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return DateRange.today();
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'month':
        // Current calendar month only (e.g. Mar 1 – Mar 31)
        return DateRange.thisMonth();
      case 'last_month':
        // Previous calendar month only (e.g. Feb 1 – Feb 28)
        return _monthOffsetRange(1);
      case 'last_2_months':
        // Exactly the month 2 months ago (e.g. Jan 1 – Jan 31)
        return _monthOffsetRange(2);
      case 'last_3_months':
        // Exactly the month 3 months ago (e.g. Dec 1 – Dec 31)
        return _monthOffsetRange(3);
      default:
        return DateRange.today();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(salesSummaryProvider(_getDateRange()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              ComboBox<String>(
                value: _period,
                items: [
                  const ComboBoxItem(value: 'today', child: Text('Today')),
                  const ComboBoxItem(value: 'week', child: Text('This Week')),
                  ComboBoxItem(
                    value: 'month',
                    child: Text('This Month - ${_monthName(0)}'),
                  ),
                  ComboBoxItem(
                    value: 'last_month',
                    child: Text('Last Month - ${_monthName(1)}'),
                  ),
                  ComboBoxItem(
                    value: 'last_2_months',
                    child: Text('Last 2 Months - ${_monthName(2)}'),
                  ),
                  ComboBoxItem(
                    value: 'last_3_months',
                    child: Text('Last 3 Months - ${_monthName(3)}'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _period = value);
                },
              ),
              const SizedBox(width: 16),
              Button(
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
                onPressed: () {
                  ref.read(salesRefreshProvider.notifier).state++;
                  ref.invalidate(salesSummaryProvider(_getDateRange()));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Summary cards
          summaryAsync.when(
            data: (summary) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Sales',
                        value: summary.totalSales.toString(),
                        subtitle: 'transactions',
                        color: AppTheme.primary(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Revenue',
                        value: Formatters.currency(summary.totalRevenue),
                        subtitle: 'total revenue',
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Cost',
                        value: Formatters.currency(summary.totalCost),
                        subtitle: 'total cost',
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Profit',
                        value: Formatters.currency(summary.totalProfit),
                        subtitle: '${summary.profitMargin.toStringAsFixed(1)}% margin',
                        color: summary.totalProfit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Credit Sales',
                        value: Formatters.currency(summary.totalCreditOutstanding),
                        subtitle: 'outstanding',
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profit Report Content
// ---------------------------------------------------------------------------

class _ProfitReportContent extends ConsumerStatefulWidget {
  const _ProfitReportContent();

  @override
  ConsumerState<_ProfitReportContent> createState() => _ProfitReportContentState();
}

class _ProfitReportContentState extends ConsumerState<_ProfitReportContent> {
  String _period = 'month';

  DateRange _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return DateRange.today();
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 'month':
        // Current calendar month only (e.g. Mar 1 – Mar 31)
        return DateRange.thisMonth();
      case 'last_month':
        // Previous calendar month only (e.g. Feb 1 – Feb 28)
        return _monthOffsetRange(1);
      case 'last_2_months':
        // Exactly the month 2 months ago (e.g. Jan 1 – Jan 31)
        return _monthOffsetRange(2);
      case 'last_3_months':
        // Exactly the month 3 months ago (e.g. Dec 1 – Dec 31)
        return _monthOffsetRange(3);
      default:
        return DateRange.thisMonth();
    }
  }

  DateRangeParams _getExpenseDateRange() {
    final range = _getDateRange();
    return DateRangeParams(startDate: range.start, endDate: range.end);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(salesSummaryProvider(_getDateRange()));
    final expenseAsync = ref.watch(expenseSummaryProvider(_getExpenseDateRange()));
    final stockLossAsync = ref.watch(stockLossSummaryProvider(_getExpenseDateRange()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ComboBox<String>(
                value: _period,
                items: [
                  const ComboBoxItem(value: 'today', child: Text('Today')),
                  const ComboBoxItem(value: 'week', child: Text('This Week')),
                  ComboBoxItem(
                    value: 'month',
                    child: Text('This Month - ${_monthName(0)}'),
                  ),
                  ComboBoxItem(
                    value: 'last_month',
                    child: Text('Last Month - ${_monthName(1)}'),
                  ),
                  ComboBoxItem(
                    value: 'last_2_months',
                    child: Text('Last 2 Months - ${_monthName(2)}'),
                  ),
                  ComboBoxItem(
                    value: 'last_3_months',
                    child: Text('Last 3 Months - ${_monthName(3)}'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _period = value);
                },
              ),
              const SizedBox(width: 16),
              Button(
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
                onPressed: () {
                  ref.read(salesRefreshProvider.notifier).state++;
                  ref.read(expenseRefreshProvider.notifier).state++;
                  ref.read(stockLossRefreshProvider.notifier).state++;
                  ref.invalidate(salesSummaryProvider(_getDateRange()));
                  ref.invalidate(expenseSummaryProvider(_getExpenseDateRange()));
                  ref.invalidate(stockLossSummaryProvider(_getExpenseDateRange()));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          summaryAsync.when(
            data: (summary) {
              return expenseAsync.when(
                data: (expenseSummary) {
                  return stockLossAsync.when(
                    data: (stockLossSummary) {
                      final totalExpenses = expenseSummary.totalAmount;
                      final totalStockLosses = stockLossSummary.totalLossAmount;
                      final netProfit = summary.totalProfit - totalExpenses - totalStockLosses;
                      final netProfitMargin = summary.totalRevenue > 0
                          ? (netProfit / summary.totalRevenue) * 100
                          : 0.0;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Profit & Loss Summary', style: FluentTheme.of(context).typography.subtitle),
                              const SizedBox(height: 24),

                              // Revenue Section
                              Text('REVENUE', style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _ProfitRow(label: 'Product Sales', value: summary.productRevenue, isPositive: true),
                              if (summary.laborIncome > 0)
                                _ProfitRow(label: 'Repair Labor/Service', value: summary.laborIncome, isPositive: true),
                              _ProfitRow(label: 'Total Revenue', value: summary.totalRevenue, isPositive: true, isBold: true),
                              const Divider(),

                              // Cost of Goods Section
                              const SizedBox(height: 8),
                              Text('COST OF GOODS SOLD', style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _ProfitRow(label: 'Cost of Goods Sold', value: summary.totalCost, isPositive: false),
                              const Divider(),

                              // Gross Profit
                              _ProfitRow(
                                label: 'Gross Profit',
                                value: summary.totalProfit,
                                isPositive: summary.totalProfit >= 0,
                                isBold: true,
                              ),
                              const Divider(),

                              // Operating Expenses Section
                              const SizedBox(height: 8),
                              Text('OPERATING EXPENSES', style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),

                              // Show expense breakdown by category
                              if (expenseSummary.categoryBreakdown.isNotEmpty) ...[
                                ...expenseSummary.categoryBreakdown.entries.map((entry) {
                                  return _ProfitRow(
                                    label: '  ${_getCategoryDisplayName(entry.key)}',
                                    value: entry.value,
                                    isPositive: false,
                                  );
                                }),
                              ] else ...[
                                _ProfitRow(label: '  No expenses recorded', value: 0, isPositive: false),
                              ],

                              _ProfitRow(
                                label: 'Total Operating Expenses',
                                value: totalExpenses,
                                isPositive: false,
                                isBold: true,
                              ),
                              const Divider(),

                              // Stock Losses Section
                              const SizedBox(height: 8),
                              Text('STOCK LOSSES', style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),

                              // Show stock loss breakdown by type
                              if (stockLossSummary.typeBreakdown.isNotEmpty) ...[
                                ...stockLossSummary.typeBreakdown.entries.map((entry) {
                                  return _ProfitRow(
                                    label: '  ${_getLossTypeDisplayName(entry.key)}',
                                    value: entry.value,
                                    isPositive: false,
                                  );
                                }),
                              ] else ...[
                                _ProfitRow(label: '  No stock losses recorded', value: 0, isPositive: false),
                              ],

                              _ProfitRow(
                                label: 'Total Stock Losses',
                                value: totalStockLosses,
                                isPositive: false,
                                isBold: true,
                              ),
                              const Divider(),

                              // Net Profit Section
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: netProfit >= 0
                                      ? AppTheme.successColor.withValues(alpha: 0.1)
                                      : AppTheme.errorColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    _ProfitRow(
                                      label: 'NET PROFIT',
                                      value: netProfit,
                                      isPositive: netProfit >= 0,
                                      isBold: true,
                                    ),
                                    const SizedBox(height: 8),
                                    _ProfitRow(
                                      label: 'Net Profit Margin',
                                      value: netProfitMargin,
                                      isPercentage: true,
                                      isPositive: netProfitMargin >= 0,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const Center(child: ProgressRing()),
                    error: (e, _) => _buildPLWithoutStockLoss(context, summary, expenseSummary),
                  );
                },
                loading: () => const Center(child: ProgressRing()),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Profit & Loss Summary', style: FluentTheme.of(context).typography.subtitle),
                        const SizedBox(height: 24),
                        _ProfitRow(label: 'Product Sales', value: summary.productRevenue, isPositive: true),
                        if (summary.laborIncome > 0)
                          _ProfitRow(label: 'Repair Labor/Service', value: summary.laborIncome, isPositive: true),
                        _ProfitRow(label: 'Total Revenue', value: summary.totalRevenue, isPositive: true, isBold: true),
                        const Divider(),
                        _ProfitRow(label: 'Cost of Goods Sold', value: summary.totalCost, isPositive: false),
                        const Divider(),
                        _ProfitRow(
                          label: 'Gross Profit',
                          value: summary.totalProfit,
                          isPositive: summary.totalProfit >= 0,
                          isBold: true,
                        ),
                        const Divider(),
                        InfoBar(
                          title: const Text('Expenses'),
                          content: const Text('Unable to load expenses'),
                          severity: InfoBarSeverity.warning,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildPLWithoutStockLoss(BuildContext context, SalesSummary summary, ExpenseSummary expenseSummary) {
    final totalExpenses = expenseSummary.totalAmount;
    final netProfit = summary.totalProfit - totalExpenses;
    final netProfitMargin = summary.totalRevenue > 0
        ? (netProfit / summary.totalRevenue) * 100
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profit & Loss Summary', style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 24),
            _ProfitRow(label: 'Product Sales', value: summary.productRevenue, isPositive: true),
            if (summary.laborIncome > 0)
              _ProfitRow(label: 'Repair Labor/Service', value: summary.laborIncome, isPositive: true),
            _ProfitRow(label: 'Total Revenue', value: summary.totalRevenue, isPositive: true, isBold: true),
            const Divider(),
            _ProfitRow(label: 'Cost of Goods Sold', value: summary.totalCost, isPositive: false),
            const Divider(),
            _ProfitRow(label: 'Gross Profit', value: summary.totalProfit, isPositive: summary.totalProfit >= 0, isBold: true),
            const Divider(),
            _ProfitRow(label: 'Total Expenses', value: totalExpenses, isPositive: false, isBold: true),
            const Divider(),
            InfoBar(
              title: const Text('Stock Losses'),
              content: const Text('Unable to load stock losses'),
              severity: InfoBarSeverity.warning,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: netProfit >= 0
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _ProfitRow(label: 'NET PROFIT (excl. stock losses)', value: netProfit, isPositive: netProfit >= 0, isBold: true),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryDisplayName(String code) {
    const categoryNames = {
      'ELECTRICITY': 'Electricity',
      'WATER': 'Water',
      'RENT': 'Rent',
      'INTERNET': 'Internet',
      'TELEPHONE': 'Telephone',
      'SALARY': 'Salary',
      'SUPPLIES': 'Office Supplies',
      'MAINTENANCE': 'Maintenance',
      'TRANSPORT': 'Transport',
      'OTHER': 'Other Expenses',
    };
    return categoryNames[code] ?? code;
  }

  String _getLossTypeDisplayName(String code) {
    return LossType.fromCode(code).displayName;
  }
}

class _ProfitRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isPositive;
  final bool isBold;
  final bool isPercentage;

  const _ProfitRow({
    required this.label,
    required this.value,
    required this.isPositive,
    this.isBold = false,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold ? FluentTheme.of(context).typography.bodyStrong : null,
          ),
          Text(
            isPercentage ? '${value.toStringAsFixed(1)}%' : Formatters.currency(value),
            style: FluentTheme.of(context).typography.body?.copyWith(
                  color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                  fontWeight: isBold ? FontWeight.bold : null,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inventory Report Content
// ---------------------------------------------------------------------------

class _InventoryReportContent extends ConsumerWidget {
  const _InventoryReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(inventoryStatsProvider);
    final inventoryAsync = ref.watch(inventoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Button(
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
                onPressed: () {
                  ref.read(inventoryRefreshProvider.notifier).state++;
                  ref.invalidate(inventoryStatsProvider);
                  ref.invalidate(inventoryProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Summary
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Products',
                    value: stats.totalProducts.toString(),
                    subtitle: 'items',
                    color: AppTheme.primary(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Total Value',
                    value: Formatters.currency(stats.totalValue),
                    subtitle: 'inventory value',
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Low Stock',
                    value: stats.lowStockCount.toString(),
                    subtitle: 'items need reorder',
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Serialized Items',
                    value: stats.serializedCount.toString(),
                    subtitle: 'in stock',
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),
          // Inventory list
          Text('Inventory Details', style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 16),
          inventoryAsync.when(
            data: (items) => Card(
              child: SizedBox(
                height: 400,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile.selectable(
                      title: Text(item.product.name),
                      subtitle: Text(item.product.code),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Qty: ${item.quantityOnHand}'),
                              Text(
                                Formatters.currency(item.totalCost),
                                style: FluentTheme.of(context).typography.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aging Report Content
// ---------------------------------------------------------------------------

class _AgingReportContent extends ConsumerWidget {
  const _AgingReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(creditSummaryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Button(
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
                onPressed: () {
                  ref.invalidate(creditSummaryProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          summaryAsync.when(
            data: (summary) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Outstanding',
                        value: Formatters.currency(summary.totalOutstanding),
                        subtitle: 'credit balance',
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Credit Customers',
                        value: summary.creditCustomersCount.toString(),
                        subtitle: 'with balance',
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Overdue Amount',
                        value: Formatters.currency(summary.overdueAmount),
                        subtitle: 'past due',
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Collected This Month',
                        value: Formatters.currency(summary.collectedThisMonth),
                        subtitle: 'payments received',
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credit Summary', style: FluentTheme.of(context).typography.subtitle),
                        const SizedBox(height: 16),
                        _AgingRow(label: 'Total Outstanding', value: summary.totalOutstanding, color: AppTheme.primary(context)),
                        _AgingRow(label: 'Overdue Amount', value: summary.overdueAmount, color: AppTheme.errorColor),
                        _AgingRow(label: 'Collected This Month', value: summary.collectedThisMonth, color: AppTheme.successColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

class _AgingRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AgingRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            Formatters.currency(value),
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Repair Report Content
// ---------------------------------------------------------------------------

class _RepairReportContent extends ConsumerWidget {
  const _RepairReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(repairSummaryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Button(
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
                onPressed: () {
                  ref.read(repairRefreshProvider.notifier).state++;
                  ref.invalidate(repairSummaryProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          summaryAsync.when(
            data: (summary) => Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Active Jobs',
                    value: summary.activeJobs.toString(),
                    subtitle: 'in progress',
                    color: AppTheme.primary(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Pending Jobs',
                    value: summary.pendingJobs.toString(),
                    subtitle: 'awaiting',
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Completed Today',
                    value: summary.completedToday.toString(),
                    subtitle: 'jobs',
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Revenue',
                    value: Formatters.currency(summary.totalRevenue),
                    subtitle: 'from repairs',
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: ProgressRing()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared stat card widget
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: Colors.grey[100],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: FluentTheme.of(context).typography.title?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: FluentTheme.of(context).typography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
