import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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
  static const ownershipsBoxName = 'ownerships';

  late Box<Receipt> _receipts;
  late Box<ImportedTransaction> _transactions;
  late Box<UserPreferences> _settings;
  late Box<String> _categories;
  late Box<String> _tags;
  late Box<ReceiptArchive> _archives;
  late Box<String> _ownerships;
  late HiveAesCipher _cipher;
  String? _currentAccountId;

  Future<void> init({
    required Uint8List encryptionKey,
    required bool migrateLegacy,
  }) async {
    _cipher = HiveAesCipher(encryptionKey);
    if (migrateLegacy) {
      await _migrateToEncryptedBoxes();
    }
    await _openEncryptedBoxes();
    await _backfillArchives();
  }

  List<Receipt> get receipts =>
      _receipts.values.where(_belongsToCurrentAccount).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
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
    _archives.values
        .where((archive) => _belongsToCurrentAccountId(archive.receiptId))
        .map((archive) => MapEntry(archive.receiptId, archive)),
  );
  ReceiptArchive? archiveFor(String receiptId) {
    if (!_belongsToCurrentAccountId(receiptId)) return null;
    return _archives.get(receiptId);
  }

  Future<void> setCurrentAccount(String? accountId) async {
    _currentAccountId = accountId;
    debugPrint('[Storage] Current account set to $_currentAccountId');
    if (accountId != null) {
      await _claimUnownedReceipts(accountId);
      await _seedAccountIfEmpty(accountId);
      debugPrint(
        '[Storage] Account ready. visibleReceipts=${receipts.length} accountId=$accountId',
      );
    }
  }

  Future<void> upsertReceipt(Receipt receipt) async {
    final ownerId = _ownerships.get(receipt.id) ?? _currentAccountId;
    debugPrint(
      '[Storage] upsertReceipt start id=${receipt.id} ownerId=$ownerId currentAccount=$_currentAccountId merchant=${receipt.merchantName}',
    );
    if (ownerId == null) {
      throw StateError('No signed-in account found for this receipt.');
    }
    if (_currentAccountId != null && ownerId != _currentAccountId) {
      throw StateError('This receipt belongs to another account.');
    }
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
    final hash = await computeReceiptHash(
      normalizedReceipt,
      archivedImagePath,
    );
    await _receipts.put(normalizedReceipt.id, normalizedReceipt);
    await _ownerships.put(normalizedReceipt.id, ownerId);
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
    debugPrint(
      '[Storage] upsertReceipt success id=${normalizedReceipt.id} ownerId=$ownerId visibleReceipts=${receipts.length}',
    );
  }

  Future<void> deleteReceipt(String id) async {
    if (!_belongsToCurrentAccountId(id)) {
      throw StateError('This receipt belongs to another account.');
    }
    final archive = _archives.get(id);
    if (archive?.isLocked == true) {
      throw StateError('Locked archive receipts cannot be deleted.');
    }
    await _receipts.delete(id);
    await _archives.delete(id);
    await _ownerships.delete(id);
  }

  Future<void> deleteReceipts(List<String> ids) async {
    for (final id in ids) {
      try {
        await deleteReceipt(id);
      } catch (error) {
        debugPrint('[Storage] Skipped delete for id=$id error=$error');
      }
    }
  }

  Future<void> upsertTransaction(ImportedTransaction transaction) =>
      _transactions.put(transaction.id, transaction);

  Future<void> savePreferences(UserPreferences preferences) =>
      _settings.put('user', preferences);

  Future<void> lockReceipt(String receiptId) async {
    if (!_belongsToCurrentAccountId(receiptId)) {
      throw StateError('This receipt belongs to another account.');
    }
    final receipt = _receipts.get(receiptId);
    if (receipt == null) return;
    final archive = _archives.get(receiptId);
    final archivedImagePath = await _archiveImage(
      receipt.id,
      receipt.imagePath,
      archive?.archivedImagePath,
    );
    final hash = await computeReceiptHash(receipt, archivedImagePath);
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
    if (!_belongsToCurrentAccountId(receiptId)) return false;
    final receipt = _receipts.get(receiptId);
    final archive = _archives.get(receiptId);
    if (receipt == null || archive == null) return false;
    final latestHash = await computeReceiptHash(
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
    if (!_belongsToCurrentAccountId(receiptId)) return;
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
  }

  Future<void> _openEncryptedBoxes() async {
    _receipts = await Hive.openBox<Receipt>(
      receiptsBoxName,
      encryptionCipher: _cipher,
    );
    _transactions = await Hive.openBox<ImportedTransaction>(
      transactionsBoxName,
      encryptionCipher: _cipher,
    );
    _settings = await Hive.openBox<UserPreferences>(
      settingsBoxName,
      encryptionCipher: _cipher,
    );
    _categories = await Hive.openBox<String>(
      categoriesBoxName,
      encryptionCipher: _cipher,
    );
    _tags = await Hive.openBox<String>(tagsBoxName, encryptionCipher: _cipher);
    _archives = await Hive.openBox<ReceiptArchive>(
      archivesBoxName,
      encryptionCipher: _cipher,
    );
    _ownerships = await Hive.openBox<String>(
      ownershipsBoxName,
      encryptionCipher: _cipher,
    );
  }

  Future<void> _migrateToEncryptedBoxes() async {
    final receipts = await Hive.openBox<Receipt>(receiptsBoxName);
    final transactions = await Hive.openBox<ImportedTransaction>(
      transactionsBoxName,
    );
    final settings = await Hive.openBox<UserPreferences>(settingsBoxName);
    final categories = await Hive.openBox<String>(categoriesBoxName);
    final tags = await Hive.openBox<String>(tagsBoxName);
    final archives = await Hive.openBox<ReceiptArchive>(archivesBoxName);
    final ownerships = await Hive.openBox<String>(ownershipsBoxName);

    final receiptMap = Map<String, Receipt>.from(receipts.toMap().cast());
    final transactionMap = Map<String, ImportedTransaction>.from(
      transactions.toMap().cast(),
    );
    final settingsMap = Map<String, UserPreferences>.from(
      settings.toMap().cast(),
    );
    final categoryMap = Map<dynamic, String>.from(categories.toMap().cast());
    final tagMap = Map<dynamic, String>.from(tags.toMap().cast());
    final archiveMap = Map<String, ReceiptArchive>.from(
      archives.toMap().cast(),
    );
    final ownershipMap = Map<String, String>.from(ownerships.toMap().cast());

    await receipts.close();
    await transactions.close();
    await settings.close();
    await categories.close();
    await tags.close();
    await archives.close();
    await ownerships.close();

    await Hive.deleteBoxFromDisk(receiptsBoxName);
    await Hive.deleteBoxFromDisk(transactionsBoxName);
    await Hive.deleteBoxFromDisk(settingsBoxName);
    await Hive.deleteBoxFromDisk(categoriesBoxName);
    await Hive.deleteBoxFromDisk(tagsBoxName);
    await Hive.deleteBoxFromDisk(archivesBoxName);
    await Hive.deleteBoxFromDisk(ownershipsBoxName);

    await _openEncryptedBoxes();
    await _receipts.putAll(receiptMap);
    await _transactions.putAll(transactionMap);
    await _settings.putAll(settingsMap);
    await _categories.putAll(categoryMap);
    await _tags.putAll(tagMap);
    await _archives.putAll(archiveMap);
    await _ownerships.putAll(ownershipMap);
  }

  bool _belongsToCurrentAccount(Receipt receipt) {
    return _belongsToCurrentAccountId(receipt.id);
  }

  bool _belongsToCurrentAccountId(String receiptId) {
    if (_currentAccountId == null) return false;
    return _ownerships.get(receiptId) == _currentAccountId;
  }

  Future<void> _claimUnownedReceipts(String accountId) async {
    for (final receipt in _receipts.values) {
      if (_ownerships.containsKey(receipt.id)) continue;
      await _ownerships.put(receipt.id, accountId);
    }
  }

  Future<void> _seedAccountIfEmpty(String accountId) async {
    final hasOwnedReceipts = _ownerships.values.any(
      (owner) => owner == accountId,
    );
    if (hasOwnedReceipts) return;

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
            unitPrice: 18.90,
            totalPrice: 18.90,
          ),
          ReceiptItem(
            name: 'Teh Tarik',
            quantity: 1,
            unitPrice: 3.50,
            totalPrice: 3.50,
          ),
          ReceiptItem(
            name: 'Sambal Sotong',
            quantity: 1,
            unitPrice: 6.30,
            totalPrice: 6.30,
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

  @visibleForTesting
  Future<String> computeReceiptHash(
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
    for (final item in receipt.items) {
      content
        ..writeln(item.name)
        ..writeln(item.quantity.toStringAsFixed(2))
        ..writeln(item.unitPrice.toStringAsFixed(2))
        ..writeln(item.totalPrice.toStringAsFixed(2));
    }
    // Only include tax fields in hash when non-zero so existing archived
    // receipts (created before these fields existed) still verify.
    if (receipt.taxAmount != 0) {
      content.writeln('tax=${receipt.taxAmount.toStringAsFixed(2)}');
    }
    if (receipt.serviceChargeAmount != 0) {
      content.writeln('svc=${receipt.serviceChargeAmount.toStringAsFixed(2)}');
    }

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
      final hash = await computeReceiptHash(
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
