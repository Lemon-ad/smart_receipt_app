import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/archive_provider.dart';
import '../providers/receipt_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import 'receipt_review_screen.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptByIdProvider(receiptId));
    final archive = ref.watch(archiveByReceiptIdProvider(receiptId));
    final prefs = ref.watch(preferencesProvider);
    final dateFormat = prefs.dateFormat;
    final currency = prefs.currency;
    if (receipt == null) {
      return const Scaffold(body: Center(child: Text('Receipt not found')));
    }
    final isLocked = archive?.isLocked ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.merchantName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  shortDate(receipt.date, format: dateFormat),
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                Text(
                  money(receipt.totalAmount, currency: currency),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (receipt.items.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...receipt.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity == item.quantity.truncateToDouble() ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2)}x ${item.name}',
                            ),
                          ),
                          Text(
                            money(item.totalPrice, currency: currency),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  _Info('Subtotal', money(receipt.items.fold(0.0, (sum, i) => sum + i.totalPrice), currency: currency)),
                  if (receipt.taxAmount > 0)
                    _Info('Tax (SST/GST)', money(receipt.taxAmount, currency: currency)),
                  if (receipt.serviceChargeAmount > 0)
                    _Info('Service charge', money(receipt.serviceChargeAmount, currency: currency)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        money(receipt.totalAmount, currency: currency),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (receipt.items.isNotEmpty) const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                _Info('Category', receipt.category),
                _Info('Payment method', receipt.paymentMethod),
                _Info('Type', receipt.type),
                _Info(
                  'Tags',
                  receipt.tags.isEmpty ? 'None' : receipt.tags.join(', '),
                ),
                if (receipt.taxAmount > 0)
                  _Info('Tax', money(receipt.taxAmount, currency: currency)),
                if (receipt.serviceChargeAmount > 0)
                  _Info('Service charge', money(receipt.serviceChargeAmount, currency: currency)),
                _Info('Source', receipt.sourceType),
                _Info(
                  'Archive',
                  isLocked ? 'Locked for tax compliance' : 'Editable',
                ),
                if (archive != null)
                  _Info('SHA256', '${archive.sha256Hash.substring(0, 18)}...'),
                if (archive != null)
                  _Info(
                    'Statement links',
                    archive.linkedStatementRefs.isEmpty
                        ? 'None'
                        : archive.linkedStatementRefs.join(', '),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receipt image',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 180,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.panel2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      receipt.imagePath != null &&
                          File(receipt.imagePath!).existsSync()
                      ? Image.file(File(receipt.imagePath!), fit: BoxFit.cover)
                      : const Icon(
                          Icons.receipt_long,
                          size: 58,
                          color: AppTheme.muted,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raw OCR text',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  receipt.rawOcrText,
                  style: const TextStyle(color: AppTheme.muted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: archive == null
                      ? null
                      : () async {
                          final verified = await ref
                              .read(archivesProvider.notifier)
                              .verify(receipt.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  verified
                                      ? 'Archive hash verified.'
                                      : 'Archive verification failed.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verify Hash'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLocked
                      ? null
                      : () async {
                          await ref
                              .read(archivesProvider.notifier)
                              .lock(receipt.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Receipt sealed for tax archive.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.lock_outline),
                  label: Text(isLocked ? 'Locked' : 'Seal Archive'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLocked
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ReceiptReviewScreen(existingReceipt: receipt),
                          ),
                        ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                  ),
                  onPressed: isLocked
                      ? null
                      : () async {
                          await ref
                              .read(receiptsProvider.notifier)
                              .remove(receipt.id);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppTheme.muted)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
