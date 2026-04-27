import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import '../providers/archive_provider.dart';
import '../providers/report_provider.dart';
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
    final monthlySeries = _monthlySeries(receipts);

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
            children: ReportRange.values.map((range) {
              final selected = ref.watch(reportRangeProvider) == range;
              return ChoiceChip(
                label: Text(_rangeLabel(range)),
                selected: selected,
                onSelected: (_) =>
                    ref.read(reportRangeProvider.notifier).setRange(range),
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
              _Summary(label: 'Total spending', value: money(total)),
              _Summary(label: 'Highest category', value: highestCategory),
              _Summary(label: 'Receipt count', value: '${receipts.length}'),
              _Summary(
                label: 'Average spend',
                value: receipts.isEmpty
                    ? money(0)
                    : money(total / receipts.length),
              ),
            ],
          ),
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
                const Text(
                  'LAST 6 MONTHS',
                  style: TextStyle(
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
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= monthlySeries.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  monthlySeries[index].label,
                                  style: const TextStyle(color: AppTheme.muted),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: _monthlyBars(monthlySeries),
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
                        amount: money(business),
                        color: AppTheme.accent,
                        alignment: CrossAxisAlignment.start,
                      ),
                    ),
                    Expanded(
                      child: _SplitLegend(
                        label: 'Personal',
                        amount: money(personal),
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

  List<_MonthlyPoint> _monthlySeries(List<Receipt> receipts) {
    final now = DateTime.now();
    return List.generate(6, (index) {
      final date = DateTime(now.year, now.month - 5 + index);
      final value = receipts
          .where((r) => r.date.year == date.year && r.date.month == date.month)
          .fold<double>(0, (sum, r) => sum + r.totalAmount);
      return _MonthlyPoint(label: monthShort(date), value: value);
    });
  }

  List<BarChartGroupData> _monthlyBars(List<_MonthlyPoint> points) {
    return List.generate(points.length, (index) {
      final point = points[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: point.value,
            color: AppTheme.indigo,
            width: 40,
            borderRadius: BorderRadius.circular(6),
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

  String _rangeLabel(ReportRange range) => switch (range) {
    ReportRange.thisMonth => 'This Month',
    ReportRange.lastMonth => 'Last Month',
    ReportRange.quarter => 'Quarter',
    ReportRange.custom => 'Custom',
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
  const _CategoryLegend({required this.categoryEntries});

  final List<MapEntry<String, double>> categoryEntries;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                money(entry.value.value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      }).toList(),
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
