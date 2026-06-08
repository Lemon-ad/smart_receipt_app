import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user_preferences.dart';
import '../providers/archive_provider.dart';
import '../providers/receipt_provider.dart';
import '../providers/security_provider.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';
import 'archive_screen.dart';
import 'categories_tags_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final security = ref.watch(securityProvider);
    final categories = ref.watch(categoriesProvider);
    final tags = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.accent.withValues(alpha: .24),
                  child: Text(
                    _initials(security.name ?? 'SR'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        security.name ?? 'Secure User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        security.email ?? 'No email configured',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Signed in · Local encrypted storage',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Preferences'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.payments_outlined,
                  title: 'Default currency',
                  value: prefs.currency,
                  onTap: () => _pickCurrency(context, ref, prefs),
                ),
                _SettingTile(
                  icon: Icons.date_range,
                  title: 'Date format',
                  value: prefs.dateFormat,
                  onTap: () => _pickDateFormat(context, ref, prefs),
                ),
                _SettingTile(
                  icon: Icons.category_outlined,
                  title: 'Categories and tags',
                  value:
                      '${categories.length} categories · ${tags.length} tags',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CategoriesTagsScreen(),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifications'),
                  value: prefs.notificationsEnabled,
                  onChanged: (value) => ref
                      .read(preferencesProvider.notifier)
                      .save(prefs.copyWith(notificationsEnabled: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Security'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                const _SettingTile(
                  icon: Icons.lock,
                  title: 'Encrypted local storage',
                  value: 'Hive AES encryption + secure key storage',
                ),
                _SettingTile(
                  icon: Icons.password,
                  title: 'Password protection',
                  value: 'Change password or PIN',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Biometric unlock'),
                  subtitle: Text(
                    security.biometricAvailable
                        ? 'Use fingerprint or Face ID for faster unlock'
                        : 'Biometric unlock is unavailable on this device',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  value: security.biometricEnabled,
                  onChanged: security.biometricAvailable
                      ? (value) => ref
                            .read(securityProvider.notifier)
                            .setBiometricEnabled(value)
                      : null,
                ),
                const _SettingTile(
                  icon: Icons.shield_outlined,
                  title: 'Session protection',
                  value: 'Password-protected sign-in with local encrypted storage',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Data'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                const _SettingTile(
                  icon: Icons.storage,
                  title: 'Local storage status',
                  value: 'Hive encrypted-ready boxes',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cloud sync placeholder'),
                  subtitle: const Text(
                    'Prepared for Firebase or Supabase later',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  value: prefs.cloudSyncEnabled,
                  onChanged: (value) => ref
                      .read(preferencesProvider.notifier)
                      .save(prefs.copyWith(cloudSyncEnabled: value)),
                ),
                _SettingTile(
                  icon: Icons.archive_outlined,
                  title: 'Tax archive',
                  value: 'View locked receipts and verify hashes',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ArchiveScreen()),
                  ),
                ),
                _SettingTile(
                  icon: Icons.file_download_outlined,
                  title: 'Export all data',
                  value: 'PDF / CSV from Reports',
                  onTap: () => _exportAll(context, ref),
                ),
                _SettingTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear local cache',
                  value: 'Keeps saved receipts',
                  onTap: () => _clearCache(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => ref.read(securityProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Smart Receipt AI v1.0.0',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'SR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    UserPreferences prefs,
  ) async {
    final currencies = ['MYR', 'SGD', 'USD', 'EUR', 'GBP'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select currency',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            ...currencies.map(
              (c) => ListTile(
                title: Text(c),
                trailing:
                    c == prefs.currency ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, c),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref
          .read(preferencesProvider.notifier)
          .save(prefs.copyWith(currency: selected));
    }
  }

  Future<void> _pickDateFormat(
    BuildContext context,
    WidgetRef ref,
    UserPreferences prefs,
  ) async {
    final formats = {
      'dd MMM yyyy': '15 Jan 2025',
      'MM/dd/yyyy': '01/15/2025',
      'yyyy-MM-dd': '2025-01-15',
      'dd/MM/yyyy': '15/01/2025',
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select date format',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            ...formats.entries.map(
              (e) => ListTile(
                title: Text(e.value),
                subtitle: Text(e.key),
                trailing: e.key == prefs.dateFormat
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref
          .read(preferencesProvider.notifier)
          .save(prefs.copyWith(dateFormat: selected));
    }
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Export all receipts',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as CSV'),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final receipts = ref.read(receiptsProvider);
    final archives = ref.read(archivesProvider);
    if (receipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipts to export.')),
      );
      return;
    }

    try {
      final service = ExportService();
      final file = choice == 'pdf'
          ? await service.exportPdf(receipts, archives: archives)
          : await service.exportCsv(receipts, archives: archives);
      await service.share(file);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear local cache?'),
        content: const Text(
          'This removes temporary files and exported reports. Your saved receipts and archives will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final temp = await getTemporaryDirectory();
      final files = temp.listSync();
      var count = 0;
      for (final entity in files) {
        try {
          if (entity is File) {
            await entity.delete();
            count++;
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
            count++;
          }
        } catch (_) {
          // ignore
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $count temporary items.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.cyan),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(value, style: const TextStyle(color: AppTheme.muted)),
      trailing:
          onTap != null ? const Icon(Icons.chevron_right) : const SizedBox(),
      onTap: onTap,
    );
  }
}
