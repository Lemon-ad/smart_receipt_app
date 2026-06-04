import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../models/imported_transaction.dart';

class PdfImportService {
  Future<List<ImportedTransaction>> extractTransactions(String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    if (path.toLowerCase().endsWith('.csv')) {
      final text = await File(path).readAsString();
      return _parseCsv(text, fileName);
    }
    final bytes = await File(path).readAsBytes();
    final text = _extractText(bytes);
    return parseTransactions(text, fileName);
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

  @visibleForTesting
  List<ImportedTransaction> parseTransactions(String text, String fileName) {
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
      ParsedRow? entry = parseLine(line, sourceHint);
      entry ??= parseMultilineEntry(lines, lines.indexOf(line), sourceHint);
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

    return parsed;
  }

  List<ImportedTransaction> _parseCsv(String text, String fileName) {
    final ids = const Uuid();
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    final rows = lines
        .map(_splitCsvLine)
        .where((row) => row.isNotEmpty)
        .toList();
    if (rows.isEmpty) return [];

    final header = rows.first.map((cell) => cell.toLowerCase().trim()).toList();
    final dateIndex = _findHeaderIndex(header, ['date', 'transaction date']);
    final descIndex = _findHeaderIndex(header, [
      'description',
      'merchant',
      'details',
      'reference',
    ]);
    final amountIndex = _findHeaderIndex(header, ['amount', 'debit', 'total']);
    final categoryIndex = _findHeaderIndex(header, ['category']);
    final typeIndex = _findHeaderIndex(header, ['type']);

    final hasHeader = dateIndex != -1 || descIndex != -1 || amountIndex != -1;
    final startIndex = hasHeader ? 1 : 0;
    final parsed = <ImportedTransaction>[];

    for (var i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;
      final dateRaw = _valueAt(row, hasHeader ? dateIndex : 0);
      final descRaw = _valueAt(row, hasHeader ? descIndex : 1);
      final amountRaw = _valueAt(row, hasHeader ? amountIndex : 2);
      if (dateRaw.isEmpty || descRaw.isEmpty || amountRaw.isEmpty) continue;

      final amount = parseAmount(amountRaw, amountRaw);
      if (amount == 0) continue;

      final description = _cleanDescription(descRaw, 'generic');
      parsed.add(
        ImportedTransaction(
          id: ids.v4(),
          sourceFileName: fileName,
          date: _parseDate(dateRaw),
          description: description,
          amount: amount,
          category: categoryIndex == -1
              ? _categoryFor(description, 'generic')
              : _valueAt(
                  row,
                  categoryIndex,
                ).ifEmpty(_categoryFor(description, 'generic')),
          type: typeIndex == -1
              ? _typeFor(description, 'generic')
              : _valueAt(
                  row,
                  typeIndex,
                ).ifEmpty(_typeFor(description, 'generic')),
          selectedForImport: true,
        ),
      );
    }

    return parsed;
  }

  static final _datePrefixPattern = RegExp(
    r'^(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3}\s+\d{4}|\d{4}-\d{2}-\d{2})',
  );

  static final _amountSuffixPattern = RegExp(
    r'(-?\d[\d,]*\.\d{2})(?:\s+(?:CR|DR))?\s*$',
    caseSensitive: false,
  );

  @visibleForTesting
  ParsedRow? parseLine(String line, String sourceHint) {
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

      final amount = parseAmount(amountRaw, line);
      if (amount == 0) continue;

      return ParsedRow(
        date: _parseDate(dateRaw),
        description: _cleanDescription(descRaw, sourceHint),
        amount: amount,
      );
    }
    return null;
  }

  @visibleForTesting
  ParsedRow? parseMultilineEntry(
    List<String> lines,
    int startIndex,
    String sourceHint,
  ) {
    final line = lines[startIndex];
    final dateMatch = _datePrefixPattern.firstMatch(line);
    if (dateMatch == null) return null;

    // Skip if this line already parses as a full entry
    if (parseLine(line, sourceHint) != null) return null;

    final date = _parseDate(dateMatch.group(1)!);
    var description = line.substring(dateMatch.end).trim();

    for (var j = 1; j <= 3 && startIndex + j < lines.length; j++) {
      final nextLine = lines[startIndex + j];

      // Stop if we hit another line that parses fully
      if (parseLine(nextLine, sourceHint) != null) break;

      final amountMatch = _amountSuffixPattern.firstMatch(nextLine);
      if (amountMatch != null) {
        final amountRaw = amountMatch.group(1)!;
        final descPart = nextLine.substring(0, amountMatch.start).trim();
        if (descPart.isNotEmpty) description = '$description $descPart';
        final amount = parseAmount(amountRaw, nextLine);
        if (amount != 0) {
          return ParsedRow(
            date: date,
            description: _cleanDescription(description, sourceHint),
            amount: amount,
          );
        }
      } else {
        // Accumulate description from intermediate lines
        description = '$description ${nextLine.trim()}';
      }
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

  @visibleForTesting
  double parseAmount(String raw, [String? fullLine]) {
    final context = fullLine ?? raw;
    final hasCredit = RegExp(r'\bCR\b', caseSensitive: false).hasMatch(context) ||
        context.contains('(');
    final cleaned = raw
        .replaceAll(',', '')
        .replaceAll('RM', '')
        .replaceAll('MYR', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll(RegExp(r'\bDR\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bCR\b', caseSensitive: false), '')
        .trim();
    final value = double.tryParse(cleaned) ?? 0;
    return hasCredit ? -value : value;
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

  int _findHeaderIndex(List<String> header, List<String> candidates) {
    for (var i = 0; i < header.length; i++) {
      if (candidates.contains(header[i])) return i;
    }
    return -1;
  }

  String _valueAt(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  List<String> _splitCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}

class ParsedRow {
  const ParsedRow({
    required this.date,
    required this.description,
    required this.amount,
  });

  final DateTime date;
  final String description;
  final double amount;
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : trim();
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
  ..._publicBankPatterns,
];
