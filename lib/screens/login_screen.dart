import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    _email.text = _email.text.isEmpty ? (security.email ?? '') : _email.text;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 30),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to access encrypted receipts and archived statements.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                if (security.accounts.isNotEmpty) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saved accounts',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: security.accounts.map((account) {
                            return ActionChip(
                              label: Text(account.name),
                              avatar: CircleAvatar(
                                radius: 11,
                                backgroundColor: AppTheme.accent.withValues(
                                  alpha: .18,
                                ),
                                child: Text(
                                  account.name.trim().isEmpty
                                      ? 'U'
                                      : account.name.trim()[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _email.text = account.email;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                AppCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      if (security.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          security.error!,
                          style: const TextStyle(color: AppTheme.rose),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
                if (security.biometricEnabled &&
                    security.biometricAvailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(securityProvider.notifier)
                        .loginWithBiometric(),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use Biometric Unlock'),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(securityProvider.notifier).enterSignupMode(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Create another account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    await ref
        .read(securityProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }
}
