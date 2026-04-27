import 'package:intl/intl.dart';

String money(num value, {String symbol = 'RM '}) =>
    NumberFormat.currency(locale: 'ms_MY', symbol: symbol).format(value);
String moneyAmount(num value) =>
    NumberFormat.currency(locale: 'ms_MY', symbol: '').format(value).trim();

String shortDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
String monthLabel(DateTime date) => DateFormat('MMMM yyyy').format(date);
String monthShort(DateTime date) => DateFormat('MMM').format(date);

String initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
