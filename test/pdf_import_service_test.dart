import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt_ai/services/pdf_import_service.dart';

void main() {
  group('PdfImportService', () {
    final service = PdfImportService();

    group('parseAmount', () {
      test('parses plain amount', () {
        expect(service.parseAmount('123.45'), 123.45);
      });

      test('parses amount with RM prefix', () {
        expect(service.parseAmount('RM 1,234.50'), 1234.50);
      });

      test('parses amount with MYR prefix', () {
        expect(service.parseAmount('MYR 99.00'), 99.00);
      });

      test('returns negative for CR indicator', () {
        expect(service.parseAmount('50.00', '50.00 CR'), -50.00);
      });

      test('returns negative for parentheses', () {
        expect(service.parseAmount('75.00', '(75.00)'), -75.00);
      });

      test('returns positive for DR indicator', () {
        expect(service.parseAmount('100.00', '100.00 DR'), 100.00);
      });
    });

    group('parseTransactions', () {
      test('parses TNG eWallet single-line entries', () {
        const text = '''
01/01/2024 Payment to Merchant A 25.50
02/01/2024 Grab ride 12.00
''';
        final result = service.parseTransactions(text, 'tng_statement.pdf');
        expect(result.length, 2);
        expect(result.first.description, contains('Merchant A'));
        expect(result.first.amount, 25.50);
      });

      test('parses Maybank entries with CR/DR', () {
        const text = '''
01/01/2024 Salary deposit 3000.00 CR
02/01/2024 Grocery purchase 150.00 DR
''';
        final result = service.parseTransactions(text, 'maybank_statement.pdf');
        expect(result.length, 2);
        expect(result.first.amount, -3000.00);
        expect(result[1].amount, 150.00);
      });

      test('handles multi-line descriptions', () {
        const text = '''
01/01/2024 Payment to Merchant ABC
for services rendered 150.00
''';
        final result = service.parseTransactions(text, 'statement.pdf');
        expect(result.length, 1);
        expect(result.first.description, contains('Merchant ABC'));
        expect(result.first.amount, 150.00);
      });

      test('returns empty list when no matches found', () {
        final result = service.parseTransactions(
          'no transactions here',
          'empty.pdf',
        );
        expect(result, isEmpty);
      });

      test('deduplicates identical entries', () {
        const text = '''
01/01/2024 Duplicate entry 50.00
01/01/2024 Duplicate entry 50.00
''';
        final result = service.parseTransactions(text, 'dupes.pdf');
        expect(result.length, 1);
      });

      test('includes Public Bank patterns in generic fallback', () {
        const text = '''
01/01/2024 PB Engage purchase 200.00
''';
        final result = service.parseTransactions(text, 'unknown.pdf');
        expect(result.length, 1);
        expect(result.first.amount, 200.00);
      });
    });
  });
}
