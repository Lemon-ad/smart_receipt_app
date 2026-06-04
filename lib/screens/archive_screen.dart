import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/archive_provider.dart';
import '../providers/receipt_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptsProvider);
    final archives = ref.watch(archivesProvider);
    final isSelecting = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelecting ? '${_selected.length} selected' : 'Tax Archive',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (isSelecting) ...[
            TextButton(
              onPressed: () => setState(() {
                if (_selected.length == receipts.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(receipts.map((r) => r.id));
                }
              }),
              child: Text(
                _selected.length == receipts.length
                    ? 'Deselect all'
                    : 'Select all',
                style: const TextStyle(color: AppTheme.text),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.verified_outlined),
              tooltip: 'Verify selected',
              onPressed: _bulkVerify,
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock selected',
              onPressed: _bulkLock,
            ),
          ],
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: receipts.length,
        itemBuilder: (context, index) {
          final receipt = receipts[index];
          final archive = archives[receipt.id];
          final isSelected = _selected.contains(receipt.id);
          final isLocked = archive?.isLocked ?? false;
          final verified = archive?.lastVerifiedAt != null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(receipt.id),
                ),
                title: Text(
                  receipt.merchantName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortDate(receipt.date)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isLocked ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: isLocked ? AppTheme.accent : AppTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLocked ? 'Locked' : 'Unlocked',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLocked ? AppTheme.accent : AppTheme.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          verified ? Icons.verified : Icons.verified_outlined,
                          size: 14,
                          color: verified ? AppTheme.green : AppTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          verified
                              ? 'Verified ${shortDate(archive!.lastVerifiedAt!)}'
                              : 'Not verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: verified ? AppTheme.green : AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                    if (archive != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Hash: ${archive.sha256Hash.substring(0, 18)}...',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.verified_outlined, size: 20),
                      tooltip: 'Verify',
                      onPressed: () => _verify(receipt.id),
                    ),
                    IconButton(
                      icon: Icon(
                        isLocked ? Icons.lock : Icons.lock_outline,
                        size: 20,
                      ),
                      tooltip: isLocked ? 'Locked' : 'Lock',
                      onPressed: isLocked ? null : () => _lock(receipt.id),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _verify(String id) async {
    final result = await ref.read(archivesProvider.notifier).verify(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Archive hash verified.'
                : 'Archive verification failed.',
          ),
        ),
      );
    }
  }

  Future<void> _lock(String id) async {
    await ref.read(archivesProvider.notifier).lock(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sealed for tax archive.')),
      );
    }
  }

  Future<void> _bulkVerify() async {
    var verified = 0;
    var failed = 0;
    for (final id in _selected.toList()) {
      final result = await ref.read(archivesProvider.notifier).verify(id);
      if (result) {
        verified++;
      } else {
        failed++;
      }
    }
    setState(() => _selected.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verified $verified receipts. $failed failed.'),
        ),
      );
    }
  }

  Future<void> _bulkLock() async {
    for (final id in _selected.toList()) {
      await ref.read(archivesProvider.notifier).lock(id);
    }
    setState(() => _selected.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected receipts locked for tax archive.'),
        ),
      );
    }
  }
}
