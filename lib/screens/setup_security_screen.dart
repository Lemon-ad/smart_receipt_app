import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class SetupSecurityScreen extends ConsumerStatefulWidget {
  const SetupSecurityScreen({super.key});

  @override
  ConsumerState<SetupSecurityScreen> createState() =>
      _SetupSecurityScreenState();
}

class _SetupSecurityScreenState extends ConsumerState<SetupSecurityScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _biometric = false;

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final isAdditionalAccount = security.configured;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const SizedBox(height: 16),
            Text(
              isAdditionalAccount
                  ? 'Create another account'
                  : 'Secure your receipt vault',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              isAdditionalAccount
                  ? 'Add a separate local account with its own sign-in and receipt space.'
                  : 'Set up local authentication, encrypted storage, and optional biometric unlock.',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                children: [
                  _Field(controller: _name, label: 'Full name'),
                  _Field(controller: _email, label: 'Email'),
                  _Field(
                    controller: _password,
                    label: 'Password',
                    obscureText: true,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable biometric unlock'),
                    subtitle: Text(
                      security.biometricAvailable
                          ? 'Use fingerprint or Face ID on supported devices'
                          : 'Biometric authentication is not available on this device',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    value: _biometric,
                    onChanged: security.biometricAvailable
                        ? (value) => setState(() => _biometric = value)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.shield_outlined),
              label: Text(
                isAdditionalAccount
                    ? 'Create Account'
                    : 'Create Secure Profile',
              ),
            ),
            if (isAdditionalAccount) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    ref.read(securityProvider.notifier).cancelSignupMode(),
                child: const Text('Back to sign in'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      _show('Name and email are required.');
      return;
    }
    if (_password.text.length < 6) {
      _show('Password must be at least 6 characters.');
      return;
    }
    await ref
        .read(securityProvider.notifier)
        .completeSetup(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          biometricEnabled: _biometric,
        );
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
