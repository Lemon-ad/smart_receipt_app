import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage_service.dart';
import '../services/security_service.dart';

class SecurityState {
  const SecurityState({
    required this.initialized,
    required this.configured,
    required this.authenticated,
    required this.locked,
    required this.biometricAvailable,
    required this.biometricEnabled,
    required this.pinEnabled,
    required this.signupMode,
    required this.accounts,
    this.currentAccountId,
    this.name,
    this.email,
    this.error,
  });

  final bool initialized;
  final bool configured;
  final bool authenticated;
  final bool locked;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final bool pinEnabled;
  final bool signupMode;
  final List<SecurityProfile> accounts;
  final String? currentAccountId;
  final String? name;
  final String? email;
  final String? error;

  SecurityState copyWith({
    bool? initialized,
    bool? configured,
    bool? authenticated,
    bool? locked,
    bool? biometricAvailable,
    bool? biometricEnabled,
    bool? pinEnabled,
    bool? signupMode,
    List<SecurityProfile>? accounts,
    Object? currentAccountId = _unset,
    Object? name = _unset,
    Object? email = _unset,
    String? error,
  }) {
    return SecurityState(
      initialized: initialized ?? this.initialized,
      configured: configured ?? this.configured,
      authenticated: authenticated ?? this.authenticated,
      locked: locked ?? this.locked,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      signupMode: signupMode ?? this.signupMode,
      accounts: accounts ?? this.accounts,
      currentAccountId: currentAccountId == _unset
          ? this.currentAccountId
          : currentAccountId as String?,
      name: name == _unset ? this.name : name as String?,
      email: email == _unset ? this.email : email as String?,
      error: error,
    );
  }

  static const initial = SecurityState(
    initialized: false,
    configured: false,
    authenticated: false,
    locked: false,
    biometricAvailable: false,
    biometricEnabled: false,
    pinEnabled: false,
    signupMode: false,
    accounts: [],
  );
}

const _unset = Object();

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(
  SecurityNotifier.new,
);

class SecurityNotifier extends Notifier<SecurityState> {
  late SecurityService _service;
  late LocalStorageService _storage;

  @override
  SecurityState build() {
    _service = ref.read(securityServiceProvider);
    _storage = ref.read(localStorageProvider);
    return SecurityState.initial;
  }

  Future<void> initialize() async {
    final accounts = await _service.listProfiles();
    final configured = accounts.isNotEmpty;
    final profile = await _service.loadCurrentProfile();
    final biometricAvailable = await _service.canUseBiometrics();
    final biometricEnabled = await _service.isBiometricEnabled();
    await _storage.setCurrentAccount(null);
    state = state.copyWith(
      initialized: true,
      configured: configured,
      authenticated: false,
      locked: false,
      biometricAvailable: biometricAvailable,
      biometricEnabled: biometricEnabled,
      pinEnabled: profile?.hasPin ?? false,
      signupMode: !configured,
      accounts: accounts,
      currentAccountId: profile?.id,
      name: profile?.name,
      email: profile?.email,
      error: null,
    );
  }

  void enterSignupMode() {
    state = state.copyWith(signupMode: true, error: null);
  }

  void cancelSignupMode() {
    if (!state.configured) return;
    state = state.copyWith(signupMode: false, error: null);
  }

  Future<bool> completeSetup({
    required String name,
    required String email,
    required String password,
    required bool biometricEnabled,
  }) async {
    try {
      final profile = await _service.createAccount(
        name: name,
        email: email,
        password: password,
        biometricEnabled: biometricEnabled,
      );
      final accounts = await _service.listProfiles();
      await _activateAccount(profile.id);
      state = state.copyWith(
        configured: true,
        authenticated: true,
        locked: false,
        biometricEnabled: biometricEnabled,
        pinEnabled: profile.hasPin,
        signupMode: false,
        accounts: accounts,
        currentAccountId: profile.id,
        name: profile.name,
        email: profile.email,
        error: null,
      );
      return true;
    } on StateError catch (error) {
      state = state.copyWith(error: error.message);
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    final profile = await _service.validateLogin(email, password);
    if (profile == null) {
      state = state.copyWith(error: 'Invalid email or password.');
      return false;
    }
    await _activateAccount(profile.id);
    state = state.copyWith(
      authenticated: true,
      locked: false,
      signupMode: false,
      currentAccountId: profile.id,
      name: profile.name,
      email: profile.email,
      biometricEnabled: profile.biometricEnabled,
      pinEnabled: profile.hasPin,
      error: null,
    );
    return true;
  }

  Future<bool> loginWithBiometric() async {
    if (!state.biometricEnabled || !state.biometricAvailable) return false;
    final ok = await _service.authenticateBiometric();
    if (!ok) return false;
    final profile = await _service.loadCurrentProfile();
    if (profile == null) return false;
    await _activateAccount(profile.id);
    state = state.copyWith(
      authenticated: true,
      locked: false,
      currentAccountId: profile.id,
      name: profile.name,
      email: profile.email,
      pinEnabled: profile.hasPin,
      error: null,
    );
    return true;
  }

  void lock() {
    if (!state.authenticated) return;
    state = state.copyWith(locked: true);
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _service.validatePin(pin);
    if (!ok) {
      state = state.copyWith(error: 'Incorrect PIN.');
      return false;
    }
    state = state.copyWith(locked: false, error: null);
    return true;
  }

  Future<bool> unlockWithPassword(String password) async {
    final ok = await _service.validateCurrentPassword(password);
    if (!ok) {
      state = state.copyWith(error: 'Incorrect password.');
      return false;
    }
    state = state.copyWith(locked: false, error: null);
    return true;
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.biometricEnabled || !state.biometricAvailable) return false;
    final ok = await _service.authenticateBiometric();
    if (!ok) return false;
    state = state.copyWith(locked: false, error: null);
    return true;
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _service.setBiometricEnabled(value);
    final accounts = await _service.listProfiles();
    state = state.copyWith(
      biometricEnabled: value,
      accounts: accounts,
      error: null,
    );
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    String? password,
  }) async {
    try {
      final profile = await _service.updateCurrentProfile(
        name: name,
        email: email,
        password: password,
        biometricEnabled: state.biometricEnabled,
      );
      final accounts = await _service.listProfiles();
      state = state.copyWith(
        accounts: accounts,
        currentAccountId: profile.id,
        name: profile.name,
        email: profile.email,
        pinEnabled: profile.hasPin,
        error: null,
      );
      return true;
    } on StateError catch (error) {
      state = state.copyWith(error: error.message);
      return false;
    }
  }

  Future<void> logout() async {
    await _service.clearSession();
    await _storage.setCurrentAccount(null);
    state = state.copyWith(
      authenticated: false,
      locked: false,
      signupMode: false,
      currentAccountId: null,
      error: null,
    );
  }

  Future<void> _activateAccount(String accountId) async {
    await _storage.setCurrentAccount(accountId);
  }
}
