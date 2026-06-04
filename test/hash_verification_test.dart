import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt_ai/models/receipt.dart';
import 'package:smart_receipt_ai/services/local_storage_service.dart';

void main() {
  group('LocalStorageService hash computation', () {
    final service = LocalStorageService();
    final now = DateTime.now();

    Receipt buildReceipt({List<ReceiptItem> items = const []}) => Receipt(
      id: 'test-id',
      merchantName: 'Merchant',
      date: DateTime(2024, 1, 1),
      totalAmount: 100.00,
      currency: 'MYR',
      category: 'Food',
      type: 'Personal',
      paymentMethod: 'Cash',
      tags: const [],
      imagePath: null,
      rawOcrText: 'OCR text',
      sourceType: 'receipt',
      createdAt: now,
      updatedAt: now,
      items: items,
    );

    test('produces consistent hash for identical receipt', () async {
      final receipt = buildReceipt();
      final hash1 = await service.computeReceiptHash(receipt, null);
      final hash2 = await service.computeReceiptHash(receipt, null);
      expect(hash1, hash2);
    });

    test('hash changes when items change', () async {
      final receiptA = buildReceipt();
      final receiptB = buildReceipt(
        items: [
          ReceiptItem(
            name: 'Item A',
            quantity: 1,
            unitPrice: 10.00,
            totalPrice: 10.00,
          ),
        ],
      );
      final hashA = await service.computeReceiptHash(receiptA, null);
      final hashB = await service.computeReceiptHash(receiptB, null);
      expect(hashA, isNot(hashB));
    });

    test('hash changes when totalAmount changes', () async {
      final receiptA = buildReceipt();
      final receiptB = receiptA.copyWith(totalAmount: 200.00);
      final hashA = await service.computeReceiptHash(receiptA, null);
      final hashB = await service.computeReceiptHash(receiptB, null);
      expect(hashA, isNot(hashB));
    });
  });
}
