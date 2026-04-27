import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/imported_transaction.dart';
import '../models/receipt.dart';
import '../models/receipt_archive.dart';
import '../models/user_preferences.dart';

final localStorageProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('LocalStorageService is provided in main.dart');
});

class LocalStorageService {
  static const receiptsBoxName = 'receipts';
  static const transactionsBoxName = 'transactions';
  static const settingsBoxName = 'settings';
  static const categoriesBoxName = 'categories';
  static const tagsBoxName = 'tags';
  static const archivesBoxName = 'archives';

  late Box<Receipt> _receipts;
  late Box<ImportedTransaction> _transactions;
  late Box<UserPreferences> _settings;
  late Box<String> _categories;
  late Box<String> _tags;
  late Box<ReceiptArchive> _archives;

  Future<void> init() async {
    _receipts = await Hive.openBox<Receipt>(receiptsBoxName);
    _transactions = await Hive.openBox<ImportedTransaction>(
      transactionsBoxName,
    );
    _settings = await Hive.openBox<UserPreferences>(settingsBoxName);
    _categories = await Hive.openBox<String>(categoriesBoxName);
    _tags = await Hive.openBox<String>(tagsBoxName);
    _archives = await Hive.openBox<ReceiptArchive>(archivesBoxName);
    await _backfillArchives();
  }

  List<Receipt> get receipts =>
      _receipts.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  List<ImportedTransaction> get transactions => _transactions.values.toList();
  UserPreferences get preferences =>
      _settings.get('user') ??
      UserPreferences(
        currency: 'MYR',
        dateFormat: 'dd MMM yyyy',
        notificationsEnabled: true,
        cloudSyncEnabled: false,
      );
  List<String> get categories => _categories.values.toList();
  List<String> get tags => _tags.values.toList();
  Map<String, ReceiptArchive> get archiveMap => Map.fromEntries(
    _archives.values.map((archive) => MapEntry(archive.receiptId, archive)),
  );
  ReceiptArchive? archiveFor(String receiptId) => _archives.get(receiptId);

  Future<void> upsertReceipt(Receipt receipt) async {
    final current = _receipts.get(receipt.id);
    final archive = _archives.get(receipt.id);
    if (archive?.isLocked == true &&
        current != null &&
        !_sameReceiptPayload(current, receipt)) {
      throw StateError('This archived receipt is locked and cannot be edited.');
    }

    final archivedImagePath = await _archiveImage(
      receipt.id,
      receipt.imagePath,
      archive?.archivedImagePath,
    );
    final normalizedReceipt = receipt.copyWith(
      imagePath: archivedImagePath ?? receipt.imagePath,
    );
    final hash = await _computeReceiptHash(
      normalizedReceipt,
      archivedImagePath,
    );
    await _receipts.put(normalizedReceipt.id, normalizedReceipt);
    await _archives.put(
      normalizedReceipt.id,
      ReceiptArchive(
        receiptId: normalizedReceipt.id,
        sha256Hash: hash,
        archivedAt: archive?.archivedAt ?? DateTime.now(),
        archivedImagePath: archivedImagePath,
        isLocked: archive?.isLocked ?? false,
        lastVerifiedAt: archive?.lastVerifiedAt,
        linkedStatementRefs: archive?.linkedStatementRefs ?? const [],
      ),
    );
  }

  Future<void> deleteReceipt(String id) async {
    final archive = _archives.get(id);
    if (archive?.isLocked == true) {
      throw StateError('Locked archive receipts cannot be deleted.');
    }
    await _receipts.delete(id);
    await _archives.delete(id);
  }

  Future<void> upsertTransaction(ImportedTransaction transaction) =>
      _transactions.put(transaction.id, transaction);

  Future<void> savePreferences(UserPreferences preferences) =>
      _settings.put('user', preferences);

  Future<void> lockReceipt(String receiptId) async {
    final receipt = _receipts.get(receiptId);
    if (receipt == null) return;
    final archive = _archives.get(receiptId);
    final archivedImagePath = await _archiveImage(
      receipt.id,
      receipt.imagePath,
      archive?.archivedImagePath,
    );
    final hash = await _computeReceiptHash(receipt, archivedImagePath);
    await _archives.put(
      receiptId,
      ReceiptArchive(
        receiptId: receiptId,
        sha256Hash: hash,
        archivedAt: archive?.archivedAt ?? DateTime.now(),
        archivedImagePath: archivedImagePath,
        isLocked: true,
        lastVerifiedAt: DateTime.now(),
        linkedStatementRefs: archive?.linkedStatementRefs ?? const [],
      ),
    );
  }

  Future<bool> verifyReceipt(String receiptId) async {
    final receipt = _receipts.get(receiptId);
    final archive = _archives.get(receiptId);
    if (receipt == null || archive == null) return false;
    final latestHash = await _computeReceiptHash(
      receipt,
      archive.archivedImagePath,
    );
    final verified = latestHash == archive.sha256Hash;
    await _archives.put(
      receiptId,
      archive.copyWith(lastVerifiedAt: DateTime.now()),
    );
    return verified;
  }

  Future<void> attachStatementReference(
    String receiptId,
    String sourceRef,
  ) async {
    final archive = _archives.get(receiptId);
    if (archive == null) return;
    final refs = [...archive.linkedStatementRefs];
    if (!refs.contains(sourceRef)) refs.add(sourceRef);
    await _archives.put(receiptId, archive.copyWith(linkedStatementRefs: refs));
  }

  Future<void> seedIfEmpty() async {
    if (_categories.isEmpty) {
      for (final category in [
        'Food',
        'Transport',
        'Groceries',
        'Utilities',
        'Travel',
        'Office',
        'Subscriptions',
      ]) {
        await _categories.add(category);
      }
    }
    if (_tags.isEmpty) {
      for (final tag in ['BIZ', 'TNG', 'CLAIM', 'TAX', 'TRAVEL']) {
        await _tags.add(tag);
      }
    }
    if (_settings.isEmpty) {
      await savePreferences(preferences);
    }
    if (_receipts.isNotEmpty) return;

    final now = DateTime.now();
    final ids = const Uuid();
    final demo = [
      Receipt(
        id: ids.v4(),
        merchantName: 'Village Park Nasi Lemak',
        date: DateTime(now.year, now.month, 21, 12, 30),
        totalAmount: 28.70,
        currency: 'MYR',
        category: 'Food',
        type: 'Personal',
        paymentMethod: 'TNG eWallet',
        tags: const ['TNG'],
        imagePath: null,
        rawOcrText:
            'Village Park Nasi Lemak\nTotal RM28.70\nPaid by TNG eWallet',
        sourceType: 'receipt',
        createdAt: now,
        updatedAt: now,
        items: [
          ReceiptItem(
            name: 'Nasi Lemak Ayam',
            quantity: 1,
            unitPrice: 18.9,
            totalPrice: 18.9,
          ),
        ],
      ),
      Receipt(
        id: ids.v4(),
        merchantName: 'Grab Malaysia',
        date: DateTime(now.year, now.month, 18, 8, 10),
        totalAmount: 16.40,
        currency: 'MYR',
        category: 'Transport',
        type: 'Business',
        paymentMethod: 'Visa',
        tags: const ['BIZ', 'CLAIM'],
        imagePath: null,
        rawOcrText: 'Grab trip receipt\nTotal RM16.40\nVisa ending 1024',
        sourceType: 'digital_receipt',
        createdAt: now,
        updatedAt: now,
      ),
      Receipt(
        id: ids.v4(),
        merchantName: 'Jaya Grocer',
        date: DateTime(now.year, now.month, 12, 19, 5),
        totalAmount: 94.85,
        currency: 'MYR',
        category: 'Groceries',
        type: 'Personal',
        paymentMethod: 'Debit Card',
        tags: const [],
        imagePath: null,
        rawOcrText: 'Jaya Grocer\nGroceries\nTotal RM94.85',
        sourceType: 'receipt',
        createdAt: now,
        updatedAt: now,
      ),
      Receipt(
        id: ids.v4(),
        merchantName: 'AirAsia',
        date: DateTime(now.year, now.month - 1, 26, 14, 20),
        totalAmount: 286.00,
        currency: 'MYR',
        category: 'Travel',
        type: 'Business',
        paymentMethod: 'Mastercard',
        tags: const ['BIZ', 'TRAVEL'],
        imagePath: null,
        rawOcrText: 'AirAsia itinerary\nKUL to PEN\nTotal MYR286.00',
        sourceType: 'statement_import',
        createdAt: now,
        updatedAt: now,
      ),
      Receipt(
        id: ids.v4(),
        merchantName: 'Maxis',
        date: DateTime(now.year, now.month - 1, 8, 9, 45),
        totalAmount: 59.00,
        currency: 'MYR',
        category: 'Utilities',
        type: 'Personal',
        paymentMethod: 'Bank Transfer',
        tags: const [],
        imagePath: null,
        rawOcrText: 'Maxis bill\nTotal RM59.00',
        sourceType: 'statement_import',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    for (final receipt in demo) {
      await upsertReceipt(receipt);
    }
  }

  bool _sameReceiptPayload(Receipt a, Receipt b) {
    return a.merchantName == b.merchantName &&
        a.date == b.date &&
        a.totalAmount == b.totalAmount &&
        a.currency == b.currency &&
        a.category == b.category &&
        a.type == b.type &&
        a.paymentMethod == b.paymentMethod &&
        a.rawOcrText == b.rawOcrText &&
        a.sourceType == b.sourceType &&
        _sameList(a.tags, b.tags);
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<String?> _archiveImage(
    String receiptId,
    String? sourcePath,
    String? existingArchivedPath,
  ) async {
    if (sourcePath == null || sourcePath.isEmpty) return existingArchivedPath;
    final source = File(sourcePath);
    if (!source.existsSync()) return existingArchivedPath;
    if (existingArchivedPath != null &&
        p.equals(sourcePath, existingArchivedPath)) {
      return existingArchivedPath;
    }

    final docs = await getApplicationDocumentsDirectory();
    final archiveDir = Directory(p.join(docs.path, 'receipt_archive'));
    if (!archiveDir.existsSync()) {
      await archiveDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final targetPath = p.join(archiveDir.path, '$receiptId$ext');
    await source.copy(targetPath);
    return targetPath;
  }

  Future<String> _computeReceiptHash(
    Receipt receipt,
    String? archivedImagePath,
  ) async {
    final content = StringBuffer()
      ..writeln(receipt.id)
      ..writeln(receipt.merchantName)
      ..writeln(receipt.date.toIso8601String())
      ..writeln(receipt.totalAmount.toStringAsFixed(2))
      ..writeln(receipt.currency)
      ..writeln(receipt.category)
      ..writeln(receipt.type)
      ..writeln(receipt.paymentMethod)
      ..writeln(receipt.tags.join(','))
      ..writeln(receipt.rawOcrText);

    final bytes = <int>[...utf8.encode(content.toString())];
    if (archivedImagePath != null && File(archivedImagePath).existsSync()) {
      bytes.addAll(await File(archivedImagePath).readAsBytes());
    }
    return sha256.convert(bytes).toString();
  }

  Future<void> _backfillArchives() async {
    for (final receipt in _receipts.values) {
      if (_archives.containsKey(receipt.id)) continue;
      final archivedImagePath = await _archiveImage(
        receipt.id,
        receipt.imagePath,
        null,
      );
      final normalizedReceipt = receipt.copyWith(
        imagePath: archivedImagePath ?? receipt.imagePath,
      );
      final hash = await _computeReceiptHash(
        normalizedReceipt,
        archivedImagePath,
      );
      await _receipts.put(normalizedReceipt.id, normalizedReceipt);
      await _archives.put(
        normalizedReceipt.id,
        ReceiptArchive(
          receiptId: normalizedReceipt.id,
          sha256Hash: hash,
          archivedAt: normalizedReceipt.createdAt,
          archivedImagePath: archivedImagePath,
          isLocked: false,
          linkedStatementRefs: const [],
        ),
      );
    }
  }
}
