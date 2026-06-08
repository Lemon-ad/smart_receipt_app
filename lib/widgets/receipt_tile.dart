import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import '../providers/archive_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ReceiptTile extends ConsumerWidget {
  const ReceiptTile({
    super.key,
    required this.receipt,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  final Receipt receipt;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(archiveByReceiptIdProvider(receipt.id));
    final hasLinks = archive?.linkedStatementRefs.isNotEmpty ?? false;
    final currency = ref.watch(preferencesProvider).currency;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent.withValues(alpha: .35)),
            ),
            child: Text(
              initials(receipt.merchantName),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              receipt.merchantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            money(receipt.totalAmount, currency: currency),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Text(
              receipt.category,
              style: const TextStyle(color: AppTheme.muted),
            ),
            if (receipt.tags.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  receipt.tags.first,
                  style: const TextStyle(fontSize: 11, color: AppTheme.green),
                ),
              ),
            ],
            if (hasLinks) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 10, color: AppTheme.cyan),
                    SizedBox(width: 4),
                    Text(
                      'Linked',
                      style: TextStyle(fontSize: 11, color: AppTheme.cyan),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            Flexible(
              child: Text(
                receipt.paymentMethod,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
