import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt_ai/models/receipt.dart';
import 'package:smart_receipt_ai/models/receipt_archive.dart';
import 'package:smart_receipt_ai/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  group('ExportService', () {
    final service = ExportService();
    final now = DateTime.now();

    final receipts = [
      Receipt(
        id: 'r1',
        merchantName: 'Test Merchant',
        date: DateTime(2024, 1, 15),
        totalAmount: 99.50,
        currency: 'MYR',
        category: 'Food',
        type: 'Personal',
        paymentMethod: 'TNG eWallet',
        tags: const ['TNG'],
        imagePath: null,
        rawOcrText: 'Test',
        sourceType: 'receipt',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final archives = {
      'r1': ReceiptArchive(
        receiptId: 'r1',
        sha256Hash:
            'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        archivedAt: now,
        archivedImagePath: null,
        isLocked: true,
        lastVerifiedAt: now,
        linkedStatementRefs: const [],
      ),
    };

    test('exportCsv includes all columns', () async {
      final file = await service.exportCsv(receipts, archives: archives);
      final content = await file.readAsString();
      expect(content, contains('Last Verified'));
      expect(content, contains('SHA256'));
      expect(content, contains('Test Merchant'));
      expect(content, contains('99.50'));
      expect(content, contains('true'));
      expect(
        content,
        contains(
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        ),
      );
    });

    test('exportPdf creates non-empty file', () async {
      final file = await service.exportPdf(receipts, archives: archives);
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(0));
    });
  });
}
