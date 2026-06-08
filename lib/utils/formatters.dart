import 'package:intl/intl.dart';

String _symbolFor(String currency) {
  return switch (currency) {
    'MYR' => 'RM ',
    'SGD' => 'S\$',
    'USD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$currency ',
  };
}

String money(num value, {String? currency, String? symbol}) =>
    NumberFormat.currency(
      locale: 'ms_MY',
      symbol: symbol ?? (currency != null ? _symbolFor(currency) : 'RM '),
    ).format(value);

String moneyAmount(num value) =>
    NumberFormat.currency(locale: 'ms_MY', symbol: '').format(value).trim();

String shortDate(DateTime date, {String? format}) =>
    DateFormat(format ?? 'dd MMM yyyy').format(date);
String monthLabel(DateTime date, {String? format}) =>
    DateFormat(format ?? 'MMMM yyyy').format(date);
String monthShort(DateTime date, {String? format}) =>
    DateFormat(format ?? 'MMM').format(date);

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
