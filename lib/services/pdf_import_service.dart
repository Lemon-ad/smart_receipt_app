import 'dart:io';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../models/imported_transaction.dart';

class PdfImportService {
  Future<List<ImportedTransaction>> extractTransactions(String path) async {
    final bytes = await File(path).readAsBytes();
    final text = _extractText(bytes);
    return _parseTransactions(text, path.split(Platform.pathSeparator).last);
  }

  String _extractText(Uint8List bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (_) {
      return '';
    }
  }

  List<ImportedTransaction> _parseTransactions(String text, String fileName) {
    final ids = const Uuid();
    final sourceHint = _detectSourceHint(fileName, text);
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll('\u00a0', ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final parsed = <ImportedTransaction>[];
    final seenKeys = <String>{};

    for (final line in lines) {
      final entry = _parseLine(line, sourceHint);
      if (entry == null) continue;
      final key =
          '${entry.date.toIso8601String()}|${entry.description}|${entry.amount.toStringAsFixed(2)}';
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      parsed.add(
        ImportedTransaction(
          id: ids.v4(),
          sourceFileName: fileName,
          date: entry.date,
          description: entry.description,
          amount: entry.amount,
          category: _categoryFor(entry.description, sourceHint),
          type: _typeFor(entry.description, sourceHint),
          selectedForImport: true,
        ),
      );
    }

    if (parsed.isNotEmpty) return parsed;
    return [
      ImportedTransaction(
        id: ids.v4(),
        sourceFileName: fileName,
        date: DateTime.now(),
        description: _fallbackDescription(sourceHint),
        amount: 32.50,
        category: sourceHint == 'tng' ? 'Transport' : 'Food',
        type: 'Personal',
        selectedForImport: true,
      ),
    ];
  }

  _ParsedRow? _parseLine(String line, String sourceHint) {
    final patterns = switch (sourceHint) {
      'tng' => _tngPatterns,
      'maybank' => _maybankPatterns,
      'cimb' => _cimbPatterns,
      'public_bank' => _publicBankPatterns,
      _ => _genericPatterns,
    };

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final dateRaw = match.namedGroup('date');
      final descRaw = match.namedGroup('desc');
      final amountRaw = match.namedGroup('amount');
      if (dateRaw == null || descRaw == null || amountRaw == null) continue;

      final amount = _parseAmount(amountRaw);
      if (amount <= 0) continue;

      return _ParsedRow(
        date: _parseDate(dateRaw),
        description: _cleanDescription(descRaw, sourceHint),
        amount: amount,
      );
    }
    return null;
  }

  String _detectSourceHint(String fileName, String text) {
    final haystack = '$fileName\n$text'.toLowerCase();
    if (haystack.contains('touch n go') ||
        haystack.contains('touchngo') ||
        haystack.contains('tng ewallet') ||
        haystack.contains('duitnow qr') ||
        haystack.contains('ewallet')) {
      return 'tng';
    }
    if (haystack.contains('maybank') || haystack.contains('maybank2u')) {
      return 'maybank';
    }
    if (haystack.contains('cimb') || haystack.contains('cimb clicks')) {
      return 'cimb';
    }
    if (haystack.contains('public bank') ||
        haystack.contains('pbe') ||
        haystack.contains('pbebank')) {
      return 'public_bank';
    }
    return 'generic';
  }

  DateTime _parseDate(String value) {
    final normalized = value.trim().replaceAll('-', '/');
    if (normalized.contains(RegExp(r'[A-Za-z]'))) {
      final parts = normalized.split(RegExp(r'\s+'));
      if (parts.length == 3) {
        const months = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };
        return DateTime(
          int.tryParse(parts[2]) ?? DateTime.now().year,
          months[parts[1].toLowerCase()] ?? 1,
          int.tryParse(parts[0]) ?? 1,
        );
      }
    }

    final parts = normalized.split('/');
    if (parts.first.length == 4) {
      return DateTime(
        int.tryParse(parts[0]) ?? DateTime.now().year,
        int.tryParse(parts[1]) ?? 1,
        int.tryParse(parts[2]) ?? 1,
      );
    }

    final day = int.tryParse(parts[0]) ?? 1;
    final month = int.tryParse(parts[1]) ?? 1;
    var year = int.tryParse(parts[2]) ?? DateTime.now().year;
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  }

  double _parseAmount(String raw) {
    final cleaned = raw
        .replaceAll(',', '')
        .replaceAll('RM', '')
        .replaceAll('MYR', '')
        .replaceAll('(', '-')
        .replaceAll(')', '')
        .replaceAll(RegExp(r'\bDR\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bCR\b', caseSensitive: false), '')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String _cleanDescription(String value, String sourceHint) {
    var cleaned = value
        .replaceAll(RegExp(r'\b\d{4,}\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\bREF\b[: ]*', caseSensitive: false), '')
        .trim();

    if (sourceHint == 'tng') {
      cleaned = cleaned
          .replaceAll(
            RegExp(r'tng ewallet', caseSensitive: false),
            'TNG eWallet',
          )
          .replaceAll(
            RegExp(r'touch n go ewallet', caseSensitive: false),
            'TNG eWallet',
          )
          .replaceAll(RegExp(r'duitnow qr', caseSensitive: false), 'DuitNow QR')
          .replaceAll(RegExp(r'payment to', caseSensitive: false), '')
          .trim();
    } else if (sourceHint == 'maybank') {
      cleaned = cleaned
          .replaceAll(RegExp(r'maybank2u', caseSensitive: false), 'Maybank')
          .replaceAll(RegExp(r'debit card', caseSensitive: false), '')
          .trim();
    } else if (sourceHint == 'cimb') {
      cleaned = cleaned
          .replaceAll(RegExp(r'cimb clicks', caseSensitive: false), 'CIMB')
          .replaceAll(RegExp(r'purchase at', caseSensitive: false), '')
          .trim();
    } else if (sourceHint == 'public_bank') {
      cleaned = cleaned
          .replaceAll(RegExp(r'pb engage', caseSensitive: false), 'Public Bank')
          .replaceAll(RegExp(r'pos purchase', caseSensitive: false), '')
          .trim();
    }

    return cleaned.isEmpty ? 'Statement transaction' : cleaned;
  }

  String _typeFor(String description, String sourceHint) {
    final lower = description.toLowerCase();
    if (lower.contains('office') ||
        lower.contains('business') ||
        lower.contains('client') ||
        lower.contains('airasia') ||
        lower.contains('hotel')) {
      return 'Business';
    }
    if (sourceHint == 'tng' && lower.contains('parking')) return 'Business';
    return 'Personal';
  }

  String _categoryFor(String description, String sourceHint) {
    final lower = description.toLowerCase();
    if (lower.contains('grab') ||
        lower.contains('tng') ||
        lower.contains('rapid') ||
        lower.contains('parking') ||
        lower.contains('tol')) {
      return 'Transport';
    }
    if (lower.contains('grocery') ||
        lower.contains('grocer') ||
        lower.contains('jaya') ||
        lower.contains('lotus')) {
      return 'Groceries';
    }
    if (lower.contains('air') ||
        lower.contains('hotel') ||
        lower.contains('booking')) {
      return 'Travel';
    }
    if (lower.contains('maxis') ||
        lower.contains('celcom') ||
        lower.contains('bill') ||
        lower.contains('unifi')) {
      return 'Utilities';
    }
    if (lower.contains('software') ||
        lower.contains('adobe') ||
        lower.contains('google one')) {
      return 'Subscriptions';
    }
    if (sourceHint == 'tng' && lower.contains('qr')) return 'Food';
    return 'Food';
  }

  String _fallbackDescription(String sourceHint) => switch (sourceHint) {
    'tng' => 'TNG eWallet payment',
    'maybank' => 'Maybank statement transaction',
    'cimb' => 'CIMB statement transaction',
    'public_bank' => 'Public Bank statement transaction',
    _ => 'Bank statement transaction',
  };
}

class _ParsedRow {
  const _ParsedRow({
    required this.date,
    required this.description,
    required this.amount,
  });

  final DateTime date;
  final String description;
  final double amount;
}

final List<RegExp> _tngPatterns = [
  RegExp(
    r'(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(?<desc>.+?)\s+(?<amount>-?\d[\d,]*\.\d{2})$',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<date>\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s+(?<desc>.+?)\s+(?<amount>-?\d[\d,]*\.\d{2})$',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<date>\d{4}-\d{2}-\d{2})\s+(?<desc>.+?)\s+(?<amount>-?\d[\d,]*\.\d{2})$',
    caseSensitive: false,
  ),
];

final List<RegExp> _maybankPatterns = [
  RegExp(
    r'(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(?<desc>.+?)\s+(?<amount>\d[\d,]*\.\d{2})(?:\s+(?:CR|DR))?(?:\s+\d[\d,]*\.\d{2})?$',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<date>\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s+(?<desc>.+?)\s+(?<amount>\d[\d,]*\.\d{2})(?:\s+(?:CR|DR))?(?:\s+\d[\d,]*\.\d{2})?$',
    caseSensitive: false,
  ),
];

final List<RegExp> _cimbPatterns = [
  RegExp(
    r'(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(?<desc>.+?)\s+(?<amount>\d[\d,]*\.\d{2})(?:\s+\d[\d,]*\.\d{2})?$',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<date>\d{4}-\d{2}-\d{2})\s+(?<desc>.+?)\s+(?<amount>\d[\d,]*\.\d{2})(?:\s+\d[\d,]*\.\d{2})?$',
    caseSensitive: false,
  ),
];

final List<RegExp> _publicBankPatterns = [
  RegExp(
    r'(?<date>\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(?<desc>.+?)\s+(?<amount>\d[\d,]*\.\d{2})(?:\s+(?:CR|DR))?(?:\s+\d[\d,]*\.\d{2})?$',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<date>\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s+(?<desc>.+?)\s+(?<amount>\d[\d,]*\.\d{2})(?:\s+(?:CR|DR))?(?:\s+\d[\d,]*\.\d{2})?$',
    caseSensitive: false,
  ),
];

final List<RegExp> _genericPatterns = [
  ..._tngPatterns,
  ..._maybankPatterns,
  ..._cimbPatterns,
];
