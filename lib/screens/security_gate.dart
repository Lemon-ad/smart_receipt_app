import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_provider.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import 'setup_security_screen.dart';

class SecurityGate extends ConsumerStatefulWidget {
  const SecurityGate({super.key});

  @override
  ConsumerState<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends ConsumerState<SecurityGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(securityProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    if (!security.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!security.configured) {
      return const SetupSecurityScreen();
    }
    if (security.signupMode) {
      return const SetupSecurityScreen();
    }
    if (!security.authenticated) {
      return const LoginScreen();
    }
    return const AppShell();
  }
}
