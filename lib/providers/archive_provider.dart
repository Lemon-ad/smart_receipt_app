import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_provider.dart';
import '../models/receipt_archive.dart';
import '../services/local_storage_service.dart';

final archivesProvider =
    NotifierProvider<ArchivesNotifier, Map<String, ReceiptArchive>>(
      ArchivesNotifier.new,
    );

class ArchivesNotifier extends Notifier<Map<String, ReceiptArchive>> {
  late LocalStorageService _storage;

  @override
  Map<String, ReceiptArchive> build() {
    // Archive state follows the current account for the same reason receipts do.
    ref.watch(securityProvider.select((state) => state.currentAccountId));
    _storage = ref.read(localStorageProvider);
    return _storage.archiveMap;
  }

  Future<void> lock(String receiptId) async {
    // In the UI this action is described as "Seal Archive".
    await _storage.lockReceipt(receiptId);
    state = _storage.archiveMap;
  }

  Future<bool> verify(String receiptId) async {
    // The boolean result is used by the details screen to tell the user whether
    // the archived record still matches its saved SHA-256 fingerprint.
    final result = await _storage.verifyReceipt(receiptId);
    state = _storage.archiveMap;
    return result;
  }
}

final archiveByReceiptIdProvider = Provider.family<ReceiptArchive?, String>((
  ref,
  receiptId,
) {
  return ref.watch(archivesProvider)[receiptId];
});
