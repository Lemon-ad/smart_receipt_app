import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pin = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.lock_outline, size: 54, color: AppTheme.cyan),
                const SizedBox(height: 16),
                Text(
                  'App locked',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your PIN or use biometrics to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                AppCard(
                  child: TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'PIN'),
                  ),
                ),
                if (security.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    security.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.rose),
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(securityProvider.notifier)
                      .unlockWithPin(_pin.text.trim()),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock with PIN'),
                ),
                if (security.biometricEnabled &&
                    security.biometricAvailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(securityProvider.notifier)
                        .unlockWithBiometric(),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use Biometric Unlock'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
