import 'package:flutter/material.dart';

import '../models/receipt.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ReceiptTile extends StatelessWidget {
  const ReceiptTile({super.key, required this.receipt, required this.onTap});

  final Receipt receipt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: Container(
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
            money(receipt.totalAmount),
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
