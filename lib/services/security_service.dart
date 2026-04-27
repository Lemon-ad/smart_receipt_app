import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  throw UnimplementedError('SecurityService is provided in main.dart');
});

class SecurityProfile {
  const SecurityProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.biometricEnabled,
  });

  final String id;
  final String name;
  final String email;
  final bool biometricEnabled;
}

class _SecurityAccount {
  const _SecurityAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.pinHash,
    required this.biometricEnabled,
  });

  final String id;
  final String name;
  final String email;
  final String passwordHash;
  final String pinHash;
  final bool biometricEnabled;

  factory _SecurityAccount.fromJson(Map<String, dynamic> json) {
    return _SecurityAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      passwordHash: json['passwordHash'] as String,
      pinHash: json['pinHash'] as String,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'pinHash': pinHash,
      'biometricEnabled': biometricEnabled,
    };
  }

  SecurityProfile toProfile() {
    return SecurityProfile(
      id: id,
      name: name,
      email: email,
      biometricEnabled: biometricEnabled,
    );
  }

  _SecurityAccount copyWith({
    String? name,
    String? email,
    String? passwordHash,
    String? pinHash,
    bool? biometricEnabled,
  }) {
    return _SecurityAccount(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}

class SecurityService {
  SecurityService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
      _localAuth = LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _accountsKey = 'security_accounts';
  static const _currentAccountKey = 'security_current_account';
  static const _hiveKeyKey = 'security_hive_key';
  static const _hiveMigratedKey = 'security_hive_migrated';

  static const _legacyNameKey = 'security_name';
  static const _legacyEmailKey = 'security_email';
  static const _legacyPasswordHashKey = 'security_password_hash';
  static const _legacyPinHashKey = 'security_pin_hash';
  static const _legacyBiometricEnabledKey = 'security_biometric_enabled';

  Future<List<SecurityProfile>> listProfiles() async {
    final accounts = await _readAccounts();
    accounts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return accounts.map((account) => account.toProfile()).toList();
  }

  Future<SecurityProfile?> loadCurrentProfile() async {
    final account = await _loadCurrentAccount();
    return account?.toProfile();
  }

  Future<bool> isConfigured() async {
    return (await _readAccounts()).isNotEmpty;
  }

  Future<SecurityProfile> createAccount({
    required String name,
    required String email,
    required String password,
    required String pin,
    required bool biometricEnabled,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final accounts = await _readAccounts();
    if (accounts.any((account) => account.email == normalizedEmail)) {
      throw StateError('An account with that email already exists.');
    }

    final account = _SecurityAccount(
      id: const Uuid().v4(),
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: _hash(password),
      pinHash: _hash(pin),
      biometricEnabled: biometricEnabled,
    );
    accounts.add(account);
    await _writeAccounts(accounts);
    await _storage.write(key: _currentAccountKey, value: account.id);
    return account.toProfile();
  }

  Future<SecurityProfile> updateCurrentProfile({
    required String name,
    required String email,
    String? password,
    String? pin,
    bool? biometricEnabled,
  }) async {
    final current = await _loadCurrentAccount();
    if (current == null) {
      throw StateError('No signed-in account found.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final accounts = await _readAccounts();
    if (accounts.any(
      (account) => account.id != current.id && account.email == normalizedEmail,
    )) {
      throw StateError('That email is already used by another account.');
    }

    final updated = current.copyWith(
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: password == null || password.isEmpty
          ? null
          : _hash(password),
      pinHash: pin == null || pin.isEmpty ? null : _hash(pin),
      biometricEnabled: biometricEnabled,
    );

    final nextAccounts = [
      for (final account in accounts)
        account.id == current.id ? updated : account,
    ];
    await _writeAccounts(nextAccounts);
    await _storage.write(key: _currentAccountKey, value: updated.id);
    return updated.toProfile();
  }

  Future<SecurityProfile?> validateLogin(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final passwordHash = _hash(password);
    final accounts = await _readAccounts();
    final match = accounts.where((account) {
      return account.email == normalizedEmail &&
          account.passwordHash == passwordHash;
    }).firstOrNull;
    if (match == null) return null;
    await _storage.write(key: _currentAccountKey, value: match.id);
    return match.toProfile();
  }

  Future<bool> validatePin(String pin) async {
    final current = await _loadCurrentAccount();
    if (current == null) return false;
    return current.pinHash == _hash(pin);
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      return supported && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final current = await _loadCurrentAccount();
    return current?.biometricEnabled ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final current = await _loadCurrentAccount();
    if (current == null) return;
    final accounts = await _readAccounts();
    final nextAccounts = [
      for (final account in accounts)
        account.id == current.id
            ? account.copyWith(biometricEnabled: value)
            : account,
    ];
    await _writeAccounts(nextAccounts);
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock your protected receipts',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> clearSession() async {
    // We intentionally keep the current-account pointer so biometric login and
    // faster account switching continue to work after sign out.
  }

  Future<Uint8List> getOrCreateHiveKey() async {
    final existing = await _storage.read(key: _hiveKeyKey);
    if (existing != null) {
      return Uint8List.fromList(base64Decode(existing));
    }
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _storage.write(key: _hiveKeyKey, value: base64Encode(bytes));
    return bytes;
  }

  Future<bool> isHiveMigrationComplete() async {
    return (await _storage.read(key: _hiveMigratedKey)) == 'true';
  }

  Future<void> markHiveMigrationComplete() async {
    await _storage.write(key: _hiveMigratedKey, value: 'true');
  }

  Future<List<_SecurityAccount>> _readAccounts() async {
    await _migrateLegacyAccountIfNeeded();
    final raw = await _storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => _SecurityAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAccounts(List<_SecurityAccount> accounts) async {
    await _storage.write(
      key: _accountsKey,
      value: jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  Future<_SecurityAccount?> _loadCurrentAccount() async {
    final currentId = await _storage.read(key: _currentAccountKey);
    final accounts = await _readAccounts();
    if (accounts.isEmpty) return null;
    if (currentId == null) return accounts.first;
    return accounts.where((account) => account.id == currentId).firstOrNull ??
        accounts.first;
  }

  Future<void> _migrateLegacyAccountIfNeeded() async {
    final accountsRaw = await _storage.read(key: _accountsKey);
    if (accountsRaw != null) return;

    final name = await _storage.read(key: _legacyNameKey);
    final email = await _storage.read(key: _legacyEmailKey);
    final passwordHash = await _storage.read(key: _legacyPasswordHashKey);
    final pinHash = await _storage.read(key: _legacyPinHashKey);
    if (name == null ||
        email == null ||
        passwordHash == null ||
        pinHash == null) {
      return;
    }

    final account = _SecurityAccount(
      id: const Uuid().v4(),
      name: name,
      email: email,
      passwordHash: passwordHash,
      pinHash: pinHash,
      biometricEnabled:
          (await _storage.read(key: _legacyBiometricEnabledKey)) == 'true',
    );
    await _writeAccounts([account]);
    await _storage.write(key: _currentAccountKey, value: account.id);
    await _storage.delete(key: _legacyNameKey);
    await _storage.delete(key: _legacyEmailKey);
    await _storage.delete(key: _legacyPasswordHashKey);
    await _storage.delete(key: _legacyPinHashKey);
    await _storage.delete(key: _legacyBiometricEnabledKey);
  }

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
