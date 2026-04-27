import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_preferences.dart';
import '../services/local_storage_service.dart';

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, UserPreferences>(
      PreferencesNotifier.new,
    );

class PreferencesNotifier extends Notifier<UserPreferences> {
  late LocalStorageService _storage;

  @override
  UserPreferences build() {
    _storage = ref.read(localStorageProvider);
    return _storage.preferences;
  }

  Future<void> save(UserPreferences preferences) async {
    await _storage.savePreferences(preferences);
    state = preferences;
  }
}

final categoriesProvider = Provider<List<String>>(
  (ref) => ref.read(localStorageProvider).categories,
);
final tagsProvider = Provider<List<String>>(
  (ref) => ref.read(localStorageProvider).tags,
);
