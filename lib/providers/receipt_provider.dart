import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../providers/archive_provider.dart';
import '../providers/security_provider.dart';
import '../models/receipt.dart';
import '../services/local_storage_service.dart';

final receiptsProvider = NotifierProvider<ReceiptsNotifier, List<Receipt>>(
  ReceiptsNotifier.new,
);

class ReceiptsNotifier extends Notifier<List<Receipt>> {
  late LocalStorageService _storage;

  @override
  List<Receipt> build() {
    ref.watch(securityProvider.select((state) => state.currentAccountId));
    _storage = ref.read(localStorageProvider);
    return _storage.receipts;
  }

  Future<void> save(Receipt receipt) async {
    await _storage.upsertReceipt(receipt);
    state = _storage.receipts;
    debugPrint(
      '[ReceiptsProvider] Saved receipt id=${receipt.id}. visibleCount=${state.length}',
    );
    ref.invalidate(archivesProvider);
  }

  Future<void> remove(String id) async {
    await _storage.deleteReceipt(id);
    state = _storage.receipts;
    debugPrint(
      '[ReceiptsProvider] Removed receipt id=$id. visibleCount=${state.length}',
    );
    ref.invalidate(archivesProvider);
  }
}

final receiptByIdProvider = Provider.family<Receipt?, String>((ref, id) {
  return ref
      .watch(receiptsProvider)
      .where((receipt) => receipt.id == id)
      .firstOrNull;
});

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
