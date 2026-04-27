import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    final security = ref.read(securityProvider);
    _name = TextEditingController(text: security.name ?? '');
    _email = TextEditingController(text: security.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              children: [
                _Field(controller: _name, label: 'Full name'),
                _Field(controller: _email, label: 'Email'),
                _Field(
                  controller: _password,
                  label: 'New password (optional)',
                  obscureText: true,
                ),
                _Field(
                  controller: _pin,
                  label: 'New 4-6 digit PIN (optional)',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Leave password and PIN blank if you want to keep the current ones.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
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
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      _show('Name and email are required.');
      return;
    }
    if (_password.text.isNotEmpty && _password.text.length < 6) {
      _show('Password must be at least 6 characters.');
      return;
    }
    final pin = _pin.text.trim();
    if (pin.isNotEmpty && pin.length < 4) {
      _show('PIN must be at least 4 digits.');
      return;
    }

    final ok = await ref
        .read(securityProvider.notifier)
        .updateProfile(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text.isEmpty ? null : _password.text,
          pin: pin.isEmpty ? null : pin,
        );
    if (!mounted || !ok) return;
    Navigator.of(context).pop();
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
