import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import '../providers/archive_provider.dart';
import '../providers/report_provider.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(filteredReportReceiptsProvider);
    final total = receipts.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final currency = ref.watch(preferencesProvider).currency;
    final range = ref.watch(reportRangeProvider);
    final customRange = ref.watch(reportCustomRangeProvider);
    final trend = ref.watch(reportTrendProvider);
    final typeFilter = ref.watch(reportTypeFilterProvider);

    final byCategory = <String, double>{};
    for (final receipt in receipts) {
      byCategory.update(
        receipt.category,
        (value) => value + receipt.totalAmount,
        ifAbsent: () => receipt.totalAmount,
      );
    }

    final categoryEntries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final business = receipts
        .where((r) => r.type == 'Business')
        .fold<double>(0, (sum, r) => sum + r.totalAmount);
    final personal = total - business;
    final highestCategory = categoryEntries.isEmpty
        ? '-'
        : categoryEntries.first.key;
    final monthlySeries = _chartSeries(receipts, range, customRange);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          const Text(
            'Spending intelligence from stored receipts',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: ReportRange.values.map((r) {
              final selected = range == r;
              return ChoiceChip(
                label: Text(_rangeLabel(r, customRange)),
                selected: selected,
                onSelected: (_) async {
                  if (r == ReportRange.custom) {
                    final now = DateTime.now();
                    final initial = customRange != null
                        ? DateTimeRange(
                            start: customRange.$1,
                            end: customRange.$2,
                          )
                        : DateTimeRange(
                            start: now.subtract(const Duration(days: 30)),
                            end: now,
                          );
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      initialDateRange: initial,
                    );
                    if (picked != null) {
                      ref
                          .read(reportCustomRangeProvider.notifier)
                          .setRange(picked.start, picked.end);
                    }
                    ref.read(reportRangeProvider.notifier).setRange(r);
                  } else {
                    ref.read(reportRangeProvider.notifier).setRange(r);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ReportTypeFilter.values.map((f) {
              final selected = typeFilter == f;
              return ChoiceChip(
                label: Text(_typeLabel(f)),
                selected: selected,
                onSelected: (_) =>
                    ref.read(reportTypeFilterProvider.notifier).setFilter(f),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _Summary(
                label: 'Total spending',
                value: money(total, currency: currency),
              ),
              _Summary(label: 'Highest category', value: highestCategory),
              _Summary(label: 'Receipt count', value: '${receipts.length}'),
              _Summary(
                label: 'Average spend',
                value: receipts.isEmpty
                    ? money(0, currency: currency)
                    : money(total / receipts.length, currency: currency),
              ),
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: 14),
            AppCard(
              child: Row(
                children: [
                  Icon(
                    (trend['change'] as double) >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: (trend['change'] as double) >= 0
                        ? AppTheme.rose
                        : AppTheme.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(trend['change'] as double).abs().toStringAsFixed(1)}% vs previous period',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${money(trend['current'] as double, currency: currency)} this period · ${money(trend['previous'] as double, currency: currency)} last period',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SPENDING BY CATEGORY',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    final chartSize = compact ? 150.0 : 170.0;
                    final centerValueStyle = Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 16 : 18,
                        );

                    if (categoryEntries.isEmpty) {
                      return const SizedBox(
                        height: 220,
                        child: Center(
                          child: Text(
                            'No spending data for this range',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: compact ? 280 : 210,
                      child: compact
                          ? Column(
                              children: [
                                SizedBox(
                                  width: chartSize,
                                  height: chartSize,
                                  child: _CategoryDonut(
                                    categoryEntries: categoryEntries,
                                    total: total,
                                    centerValueStyle: centerValueStyle,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Expanded(
                                  child: _CategoryLegend(
                                    categoryEntries: categoryEntries,
                                    currency: currency,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                SizedBox(
                                  width: chartSize,
                                  height: chartSize,
                                  child: _CategoryDonut(
                                    categoryEntries: categoryEntries,
                                    total: total,
                                    centerValueStyle: centerValueStyle,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _CategoryLegend(
                                    categoryEntries: categoryEntries,
                                    currency: currency,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chartTitle(range, customRange),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: _maxChartY(monthlySeries),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _chartInterval(monthlySeries),
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppTheme.border.withValues(alpha: .55),
                          strokeWidth: 1,
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppTheme.panel2,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              moneyAmount(rod.toY),
                              const TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= monthlySeries.length) {
                                return const SizedBox.shrink();
                              }
                              final step = _bottomLabelStep(
                                monthlySeries.length,
                              );
                              final isLast = index == monthlySeries.length - 1;
                              if (index % step != 0 && !isLast) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  monthlySeries[index].label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11,
                                    height: 1.15,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: _monthlyBars(
                        monthlySeries,
                        showLabels: monthlySeries.length <= 6,
                        width: monthlySeries.length > 10
                            ? 18
                            : monthlySeries.length > 6
                            ? 26
                            : 40,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PERSONAL VS BUSINESS',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Expanded(
                          flex: total == 0
                              ? 1
                              : (business * 100).round().clamp(1, 999999),
                          child: Container(color: AppTheme.accent),
                        ),
                        Expanded(
                          flex: total == 0
                              ? 1
                              : (personal * 100).round().clamp(1, 999999),
                          child: Container(color: AppTheme.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SplitLegend(
                        label: 'Business',
                        amount: money(business, currency: currency),
                        color: AppTheme.accent,
                        alignment: CrossAxisAlignment.start,
                      ),
                    ),
                    Expanded(
                      child: _SplitLegend(
                        label: 'Personal',
                        amount: money(personal, currency: currency),
                        color: AppTheme.green,
                        alignment: CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportCsv(ref),
                  icon: const Icon(Icons.table_view),
                  label: const Text('Export CSV'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportPdf(ref),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(WidgetRef ref) async {
    final service = ExportService();
    final file = await service.exportCsv(
      ref.read(filteredReportReceiptsProvider),
      archives: ref.read(archivesProvider),
    );
    await service.share(file);
  }

  Future<void> _exportPdf(WidgetRef ref) async {
    final service = ExportService();
    final file = await service.exportPdf(
      ref.read(filteredReportReceiptsProvider),
      archives: ref.read(archivesProvider),
    );
    await service.share(file);
  }

  List<_MonthlyPoint> _chartSeries(
    List<Receipt> receipts,
    ReportRange range,
    (DateTime, DateTime)? customRange,
  ) {
    final now = DateTime.now();

    switch (range) {
      case ReportRange.thisMonth:
        final start = DateTime(now.year, now.month);
        final daysInMonth = DateTime(
          now.year,
          now.month + 1,
        ).difference(start).inDays;
        final weeks = (daysInMonth / 7).ceil();
        return List.generate(weeks, (index) {
          final weekStart = start.add(Duration(days: index * 7));
          final weekEnd = weekStart.add(const Duration(days: 6));
          final value = receipts
              .where(
                (r) => !r.date.isBefore(weekStart) && !r.date.isAfter(weekEnd),
              )
              .fold<double>(0, (sum, r) => sum + r.totalAmount);
          return _MonthlyPoint(label: 'W${index + 1}', value: value);
        });
      case ReportRange.lastMonth:
        final start = DateTime(now.year, now.month - 1);
        final daysInMonth = DateTime(
          now.year,
          now.month,
        ).difference(start).inDays;
        final weeks = (daysInMonth / 7).ceil();
        return List.generate(weeks, (index) {
          final weekStart = start.add(Duration(days: index * 7));
          final weekEnd = weekStart.add(const Duration(days: 6));
          final value = receipts
              .where(
                (r) => !r.date.isBefore(weekStart) && !r.date.isAfter(weekEnd),
              )
              .fold<double>(0, (sum, r) => sum + r.totalAmount);
          return _MonthlyPoint(label: 'W${index + 1}', value: value);
        });
      case ReportRange.quarter:
        return List.generate(3, (index) {
          final date = DateTime(now.year, now.month - 2 + index);
          final value = receipts
              .where(
                (r) => r.date.year == date.year && r.date.month == date.month,
              )
              .fold<double>(0, (sum, r) => sum + r.totalAmount);
          return _MonthlyPoint(label: monthShort(date), value: value);
        });
      case ReportRange.custom:
        if (customRange == null) {
          return List.generate(6, (index) {
            final date = DateTime(now.year, now.month - 5 + index);
            final value = receipts
                .where(
                  (r) => r.date.year == date.year && r.date.month == date.month,
                )
                .fold<double>(0, (sum, r) => sum + r.totalAmount);
            return _MonthlyPoint(label: monthShort(date), value: value);
          });
        }
        final start = customRange.$1;
        final end = customRange.$2;
        final days = end.difference(start).inDays + 1;
        if (days <= 7) {
          return List.generate(days, (index) {
            final date = start.add(Duration(days: index));
            final value = receipts
                .where(
                  (r) =>
                      r.date.year == date.year &&
                      r.date.month == date.month &&
                      r.date.day == date.day,
                )
                .fold<double>(0, (sum, r) => sum + r.totalAmount);
            return _MonthlyPoint(
              label: '${date.day}/${date.month}',
              value: value,
            );
          });
        }
        if (days <= 21) {
          return _groupByFixedDayBuckets(
            receipts,
            start,
            end,
            bucketSize: 7,
            labelBuilder: (bucketEnd, bucketStart, index) =>
                _weekBucketLabel(index, bucketStart, bucketEnd),
          );
        }
        if (days <= 31) {
          return _groupByFixedDayBuckets(
            receipts,
            start,
            end,
            bucketSize: (days / 4).ceil(),
            labelBuilder: (bucketEnd, bucketStart, index) =>
                _weekBucketLabel(index, bucketStart, bucketEnd),
          );
        }
        if (days <= 62) {
          return _groupByFixedDayBuckets(
            receipts,
            start,
            end,
            bucketSize: 7,
            labelBuilder: (_, bucketStart, index) =>
                '${monthShort(bucketStart)}/${index + 1}',
          );
        }
        if (days <= 730) {
          return _groupByMonths(receipts, start, end);
        }
        if (days <= 1460) {
          return _groupByQuarters(receipts, start, end);
        }
        return _groupByYears(receipts, start, end);
    }
  }

  List<_MonthlyPoint> _groupByFixedDayBuckets(
    List<Receipt> receipts,
    DateTime start,
    DateTime end, {
    required int bucketSize,
    required String Function(
      DateTime bucketEnd,
      DateTime bucketStart,
      int index,
    )
    labelBuilder,
  }) {
    final points = <_MonthlyPoint>[];
    var bucketStart = start;
    var index = 0;
    while (!bucketStart.isAfter(end)) {
      final candidateEnd = bucketStart.add(Duration(days: bucketSize - 1));
      final bucketEnd = candidateEnd.isAfter(end) ? end : candidateEnd;
      final value = receipts
          .where(
            (r) => !r.date.isBefore(bucketStart) && !r.date.isAfter(bucketEnd),
          )
          .fold<double>(0, (sum, r) => sum + r.totalAmount);
      points.add(
        _MonthlyPoint(
          label: labelBuilder(bucketEnd, bucketStart, index),
          value: value,
        ),
      );
      bucketStart = bucketEnd.add(const Duration(days: 1));
      index++;
    }
    return points;
  }

  List<_MonthlyPoint> _groupByMonths(
    List<Receipt> receipts,
    DateTime start,
    DateTime end,
  ) {
    final months = <_MonthlyPoint>[];
    var current = DateTime(start.year, start.month);
    final endMonth = DateTime(end.year, end.month);
    while (!current.isAfter(endMonth)) {
      final value = receipts
          .where(
            (r) => r.date.year == current.year && r.date.month == current.month,
          )
          .fold<double>(0, (sum, r) => sum + r.totalAmount);
      months.add(_MonthlyPoint(label: monthShort(current), value: value));
      current = DateTime(current.year, current.month + 1);
    }
    return months;
  }

  List<_MonthlyPoint> _groupByQuarters(
    List<Receipt> receipts,
    DateTime start,
    DateTime end,
  ) {
    final points = <_MonthlyPoint>[];
    var current = DateTime(start.year, ((start.month - 1) ~/ 3) * 3 + 1);
    while (!current.isAfter(end)) {
      final quarterEnd = DateTime(current.year, current.month + 3, 0);
      final value = receipts
          .where(
            (r) => !r.date.isBefore(current) && !r.date.isAfter(quarterEnd),
          )
          .fold<double>(0, (sum, r) => sum + r.totalAmount);
      final quarter = ((current.month - 1) ~/ 3) + 1;
      points.add(_MonthlyPoint(label: 'Q$quarter', value: value));
      current = DateTime(current.year, current.month + 3);
    }
    return points;
  }

  List<_MonthlyPoint> _groupByYears(
    List<Receipt> receipts,
    DateTime start,
    DateTime end,
  ) {
    return [
      for (var year = start.year; year <= end.year; year++)
        _MonthlyPoint(
          label: '$year',
          value: receipts
              .where((r) => r.date.year == year)
              .fold<double>(0, (sum, r) => sum + r.totalAmount),
        ),
    ];
  }

  List<BarChartGroupData> _monthlyBars(
    List<_MonthlyPoint> points, {
    double? width,
    bool showLabels = false,
  }) {
    return List.generate(points.length, (index) {
      final point = points[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: point.value,
            color: AppTheme.indigo,
            width: width ?? (points.length > 12 ? 16 : 40),
            borderRadius: BorderRadius.circular(6),
            label: showLabels && point.value > 0
                ? BarChartRodLabel(
                    show: true,
                    text: moneyAmount(point.value),
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  )
                : const BarChartRodLabel(show: false),
          ),
        ],
      );
    });
  }

  double _maxChartY(List<_MonthlyPoint> points) {
    final max = points.fold<double>(
      0,
      (current, point) => point.value > current ? point.value : current,
    );
    if (max <= 0) {
      return 100;
    }
    return max * 1.25;
  }

  double _chartInterval(List<_MonthlyPoint> points) => _maxChartY(points) / 4;

  int _bottomLabelStep(int pointCount) {
    if (pointCount <= 4) return 1;
    if (pointCount <= 6) return 2;
    if (pointCount <= 8) return 2;
    return (pointCount / 4).ceil();
  }

  String _weekBucketLabel(int index, DateTime bucketStart, DateTime bucketEnd) {
    return 'W${index + 1}\n${bucketStart.day}/${bucketStart.month}-${bucketEnd.day}/${bucketEnd.month}';
  }

  String _rangeLabel(
    ReportRange range,
    (DateTime, DateTime)? custom,
  ) => switch (range) {
    ReportRange.thisMonth => 'This Month',
    ReportRange.lastMonth => 'Last Month',
    ReportRange.quarter => 'Quarter',
    ReportRange.custom =>
      custom != null
          ? '${custom.$1.day}/${custom.$1.month}–${custom.$2.day}/${custom.$2.month}'
          : 'Custom',
  };

  String _typeLabel(ReportTypeFilter filter) => switch (filter) {
    ReportTypeFilter.all => 'All',
    ReportTypeFilter.business => 'Business',
    ReportTypeFilter.personal => 'Personal',
  };

  String _chartTitle(ReportRange range, (DateTime, DateTime)? custom) =>
      switch (range) {
        ReportRange.thisMonth => 'THIS MONTH',
        ReportRange.lastMonth => 'LAST MONTH',
        ReportRange.quarter => 'LAST 3 MONTHS',
        ReportRange.custom => 'CUSTOM RANGE',
      };
}

const _palette = [
  Color(0xFFF5B544),
  Color(0xFF4FB6F4),
  Color(0xFFA66AF4),
  Color(0xFF3DD3A3),
  Color(0xFF33D1CC),
  Color(0xFFFF8A4C),
  Color(0xFFF06292),
];

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ],
      ),
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({
    required this.categoryEntries,
    required this.total,
    required this.centerValueStyle,
  });

  final List<MapEntry<String, double>> categoryEntries;
  final double total;
  final TextStyle? centerValueStyle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 46,
            startDegreeOffset: -90,
            sections: categoryEntries.asMap().entries.map((entry) {
              return PieChartSectionData(
                color: _palette[entry.key % _palette.length],
                value: entry.value.value,
                title: '',
                radius: 24,
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RM',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  moneyAmount(total),
                  maxLines: 1,
                  style: centerValueStyle?.copyWith(
                    fontSize: (centerValueStyle?.fontSize ?? 18) + 2,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'total',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({
    required this.categoryEntries,
    required this.currency,
  });

  final List<MapEntry<String, double>> categoryEntries;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: categoryEntries.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _palette[entry.key % _palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  money(entry.value.value, currency: currency),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SplitLegend extends StatelessWidget {
  const _SplitLegend({
    required this.label,
    required this.amount,
    required this.color,
    required this.alignment,
  });

  final String label;
  final String amount;
  final Color color;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppTheme.muted)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          amount,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ],
    );
  }
}

class _MonthlyPoint {
  const _MonthlyPoint({required this.label, required this.value});

  final String label;
  final double value;
}
