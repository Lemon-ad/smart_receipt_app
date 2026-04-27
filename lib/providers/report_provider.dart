import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import 'receipt_provider.dart';

enum ReportRange { thisMonth, lastMonth, quarter, custom }

final reportRangeProvider = NotifierProvider<ReportRangeNotifier, ReportRange>(
  ReportRangeNotifier.new,
);

class ReportRangeNotifier extends Notifier<ReportRange> {
  @override
  ReportRange build() => ReportRange.thisMonth;

  void setRange(ReportRange range) => state = range;
}

final filteredReportReceiptsProvider = Provider<List<Receipt>>((ref) {
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
      start = DateTime(now.year, now.month - 5);
      end = DateTime(now.year, now.month + 1);
  }
  return receipts
      .where((r) => !r.date.isBefore(start) && r.date.isBefore(end))
      .toList();
});
