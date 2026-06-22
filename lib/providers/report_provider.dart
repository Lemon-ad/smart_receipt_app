import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import 'receipt_provider.dart';

enum ReportRange { thisMonth, lastMonth, quarter, custom }

enum ReportTypeFilter { all, business, personal }

final reportRangeProvider = NotifierProvider<ReportRangeNotifier, ReportRange>(
  ReportRangeNotifier.new,
);

class ReportRangeNotifier extends Notifier<ReportRange> {
  @override
  ReportRange build() => ReportRange.thisMonth;

  void setRange(ReportRange range) => state = range;
}

final reportTypeFilterProvider =
    NotifierProvider<ReportTypeFilterNotifier, ReportTypeFilter>(
      ReportTypeFilterNotifier.new,
    );

class ReportTypeFilterNotifier extends Notifier<ReportTypeFilter> {
  @override
  ReportTypeFilter build() => ReportTypeFilter.all;

  void setFilter(ReportTypeFilter filter) => state = filter;
}

final reportCustomRangeProvider =
    NotifierProvider<ReportCustomRangeNotifier, (DateTime, DateTime)?>(
      ReportCustomRangeNotifier.new,
    );

class ReportCustomRangeNotifier extends Notifier<(DateTime, DateTime)?> {
  @override
  (DateTime, DateTime)? build() => null;

  void setRange(DateTime start, DateTime end) => state = (start, end);
}

final filteredReportReceiptsProvider = Provider<List<Receipt>>((ref) {
  // Reporting is derived directly from stored receipts, so every save/edit
  // automatically flows into the dashboard without a second reporting table.
  final range = ref.watch(reportRangeProvider);
  final receipts = ref.watch(receiptsProvider);
  final now = DateTime.now();
  late DateTime start;
  late DateTime end;
  switch (range) {
    case ReportRange.thisMonth:
      start = DateTime(now.year, now.month);
      end = DateTime(now.year, now.month + 1);
    case ReportRange.lastMonth:
      start = DateTime(now.year, now.month - 1);
      end = DateTime(now.year, now.month);
    case ReportRange.quarter:
      start = DateTime(now.year, now.month - 2);
      end = DateTime(now.year, now.month + 1);
    case ReportRange.custom:
      final custom = ref.watch(reportCustomRangeProvider);
      if (custom != null) {
        // Adding one day makes the end date inclusive for the user while still
        // using an exclusive upper bound in code.
        start = DateTime(custom.$1.year, custom.$1.month, custom.$1.day);
        end = DateTime(custom.$2.year, custom.$2.month, custom.$2.day + 1);
      } else {
        start = DateTime(now.year, now.month - 1);
        end = DateTime(now.year, now.month + 1);
      }
  }

  final typeFilter = ref.watch(reportTypeFilterProvider);
  return receipts
      .where((r) => !r.date.isBefore(start) && r.date.isBefore(end))
      .where((r) {
        return switch (typeFilter) {
          ReportTypeFilter.all => true,
          ReportTypeFilter.business => r.type == 'Business',
          ReportTypeFilter.personal => r.type == 'Personal',
        };
      })
      .toList();
});

final reportTrendProvider = Provider<Map<String, dynamic>?>((ref) {
  // Trend compares the current visible period against the previous equivalent
  // period to make the percentage change fair across different ranges.
  final range = ref.watch(reportRangeProvider);
  final receipts = ref.watch(receiptsProvider);
  final now = DateTime.now();

  late DateTime currentStart;
  late DateTime currentEnd;
  late DateTime previousStart;
  late DateTime previousEnd;

  switch (range) {
    case ReportRange.thisMonth:
      currentStart = DateTime(now.year, now.month);
      currentEnd = DateTime(now.year, now.month + 1);
      previousStart = DateTime(now.year, now.month - 1);
      previousEnd = DateTime(now.year, now.month);
    case ReportRange.lastMonth:
      currentStart = DateTime(now.year, now.month - 1);
      currentEnd = DateTime(now.year, now.month);
      previousStart = DateTime(now.year, now.month - 2);
      previousEnd = DateTime(now.year, now.month - 1);
    case ReportRange.quarter:
      currentStart = DateTime(now.year, now.month - 2);
      currentEnd = DateTime(now.year, now.month + 1);
      previousStart = DateTime(now.year, now.month - 5);
      previousEnd = DateTime(now.year, now.month - 2);
    case ReportRange.custom:
      final custom = ref.watch(reportCustomRangeProvider);
      if (custom != null) {
        final duration = custom.$2.difference(custom.$1);
        currentStart = DateTime(custom.$1.year, custom.$1.month, custom.$1.day);
        currentEnd = DateTime(
          custom.$2.year,
          custom.$2.month,
          custom.$2.day + 1,
        );
        previousStart = currentStart.subtract(
          duration + const Duration(days: 1),
        );
        previousEnd = currentStart;
      } else {
        return null;
      }
  }

  final currentTotal = receipts
      .where(
        (r) => !r.date.isBefore(currentStart) && r.date.isBefore(currentEnd),
      )
      .fold<double>(0, (sum, r) => sum + r.totalAmount);

  final previousTotal = receipts
      .where(
        (r) => !r.date.isBefore(previousStart) && r.date.isBefore(previousEnd),
      )
      .fold<double>(0, (sum, r) => sum + r.totalAmount);

  if (previousTotal <= 0) return null;

  final change = ((currentTotal - previousTotal) / previousTotal) * 100;
  return {'current': currentTotal, 'previous': previousTotal, 'change': change};
});
