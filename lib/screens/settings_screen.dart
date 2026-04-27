import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
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
                  child: const Text(
                    'AL',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alya Lim',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'alya@example.com',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Local sync ready · Cloud placeholder',
                        style: TextStyle(color: AppTheme.green, fontSize: 12),
                      ),
                    ],
                  ),
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
                ),
                _SettingTile(
                  icon: Icons.date_range,
                  title: 'Date format',
                  value: prefs.dateFormat,
                ),
                _SettingTile(
                  icon: Icons.category_outlined,
                  title: 'Categories and tags',
                  value: '7 categories · 5 tags',
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
                const _SettingTile(
                  icon: Icons.file_download_outlined,
                  title: 'Export all data',
                  value: 'PDF / CSV from Reports',
                ),
                const _SettingTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear local cache',
                  value: 'Keeps saved receipts',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {},
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
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.cyan),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(value, style: const TextStyle(color: AppTheme.muted)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
