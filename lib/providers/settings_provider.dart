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

final categoriesProvider =
    NotifierProvider<CategoriesNotifier, List<String>>(
      CategoriesNotifier.new,
    );

class CategoriesNotifier extends Notifier<List<String>> {
  late LocalStorageService _storage;

  @override
  List<String> build() {
    _storage = ref.read(localStorageProvider);
    return _storage.categories;
  }

  Future<void> add(String category) async {
    await _storage.addCategory(category);
    state = _storage.categories;
  }

  Future<void> remove(String category) async {
    await _storage.removeCategory(category);
    state = _storage.categories;
  }
}

final tagsProvider = NotifierProvider<TagsNotifier, List<String>>(
  TagsNotifier.new,
);

class TagsNotifier extends Notifier<List<String>> {
  late LocalStorageService _storage;

  @override
  List<String> build() {
    _storage = ref.read(localStorageProvider);
    return _storage.tags;
  }

  Future<void> add(String tag) async {
    await _storage.addTag(tag);
    state = _storage.tags;
  }

  Future<void> remove(String tag) async {
    await _storage.removeTag(tag);
    state = _storage.tags;
  }
}
