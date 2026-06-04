import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/imported_transaction.dart';
import '../models/receipt.dart';
import '../providers/receipt_provider.dart';
import '../services/local_storage_service.dart';
import '../services/pdf_import_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';

class StatementImportScreen extends ConsumerStatefulWidget {
  const StatementImportScreen({super.key});

  @override
  ConsumerState<StatementImportScreen> createState() =>
      _StatementImportScreenState();
}

class _StatementImportScreenState extends ConsumerState<StatementImportScreen> {
  List<ImportedTransaction> _transactions = [];
  bool _loading = false;
  String? _fileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _loading = true;
      _fileName = result.files.single.name;
    });
    final rows = await PdfImportService().extractTransactions(
      result.files.single.path!,
    );
    setState(() {
      _transactions = rows;
      _loading = false;
    });
  }

  Future<void> _importSelected() async {
    final ids = const Uuid();
    final storage = ref.read(localStorageProvider);
    var receipts = [...ref.read(receiptsProvider)];

    for (final tx in _transactions.where((t) => t.selectedForImport)) {
      if (_isDuplicate(tx, receipts)) continue;

      final match = _findMatch(tx, receipts);
      final sourceRef =
          '${tx.sourceFileName} · ${shortDate(tx.date)} · ${money(tx.amount)}';

      if (match != null && !(storage.archiveFor(match.id)?.isLocked ?? false)) {
        final updated = match.copyWith(
          category: tx.category,
          paymentMethod: _statementPaymentMethod(tx),
          tags: _mergedTags(match.tags, tx.sourceFileName),
          rawOcrText:
              '${match.rawOcrText}\n\nMatched statement entry: $sourceRef',
          sourceType: 'receipt+statement',
          updatedAt: DateTime.now(),
        );
        await ref.read(receiptsProvider.notifier).save(updated);
        await storage.attachStatementReference(match.id, sourceRef);
        receipts = receipts
            .map((receipt) => receipt.id == match.id ? updated : receipt)
            .toList();
        continue;
      }

      final created = Receipt(
        id: ids.v4(),
        merchantName: tx.description,
        date: tx.date,
        totalAmount: tx.amount,
        currency: 'MYR',
        category: tx.category,
        type: tx.type,
        paymentMethod: _statementPaymentMethod(tx),
        tags: _mergedTags(const [], tx.sourceFileName),
        imagePath: null,
        rawOcrText: 'Imported from statement: $sourceRef',
        sourceType: 'statement_import',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(receiptsProvider.notifier).save(created);
      await storage.attachStatementReference(created.id, sourceRef);
      receipts.add(created);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _transactions.where((t) => t.selectedForImport).length;
    final receipts = ref.watch(receiptsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Import Statement')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bank or TNG eWallet PDF / CSV',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _fileName == null
                      ? 'Imports PDF statements or CSV exports, detects TNG or local bank transaction rows, and lets you confirm entries before adding them as expenses.'
                      : 'Detected source: ${_sourceLabel(_fileName!)} · ${_formatLabel(_fileName!)}',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_fileName ?? 'Choose PDF or CSV'),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(18),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 14),
          ..._transactions.map((tx) {
            final match = _findMatch(tx, receipts);
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: tx.selectedForImport,
                onChanged: (value) => setState(() {
                  _transactions = _transactions
                      .map(
                        (item) => item.id == tx.id
                            ? item.copyWith(selectedForImport: value ?? false)
                            : item,
                      )
                      .toList();
                }),
                title: Text(
                  tx.description,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  match == null
                      ? '${shortDate(tx.date)} · ${tx.category} · ${tx.type} · ${_sourceLabel(tx.sourceFileName)}'
                      : '${shortDate(tx.date)} · ${tx.category} · Matches ${match.merchantName} · ${_sourceLabel(tx.sourceFileName)}',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                secondary: Text(
                  money(tx.amount),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            );
          }),
          if (_transactions.isNotEmpty) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: selected == 0 ? null : _importSelected,
              icon: const Icon(Icons.add_task),
              label: Text('Import $selected transactions'),
            ),
          ],
        ],
      ),
    );
  }

  Receipt? _findMatch(ImportedTransaction tx, List<Receipt> receipts) {
    Receipt? best;
    var bestScore = 0.0;
    for (final receipt in receipts) {
      final amountGap = (receipt.totalAmount - tx.amount).abs();
      if (amountGap > 0.05) continue;
      final dayGap = (receipt.date.difference(tx.date).inHours.abs() / 24)
          .round();
      if (dayGap > 4) continue;

      var score = 1.0 - (amountGap * 5);
      score += dayGap == 0
          ? 0.6
          : dayGap == 1
          ? 0.4
          : 0.2;
      if (_normalized(receipt.merchantName) == _normalized(tx.description)) {
        score += 1.0;
      } else if (_normalized(
            tx.description,
          ).contains(_normalized(receipt.merchantName)) ||
          _normalized(
            receipt.merchantName,
          ).contains(_normalized(tx.description))) {
        score += 0.5;
      }
      if (score > bestScore) {
        bestScore = score;
        best = receipt;
      }
    }
    return bestScore >= 1.2 ? best : null;
  }

  bool _isDuplicate(ImportedTransaction tx, List<Receipt> receipts) {
    for (final receipt in receipts) {
      final amountGap = (receipt.totalAmount - tx.amount).abs();
      if (amountGap > 0.01) continue;
      final dayGap = receipt.date.difference(tx.date).inDays.abs();
      if (dayGap > 1) continue;
      final normalizedDesc = _normalized(tx.description);
      final normalizedMerchant = _normalized(receipt.merchantName);
      final descMatch = normalizedMerchant.contains(normalizedDesc) ||
          normalizedDesc.contains(normalizedMerchant) ||
          receipt.rawOcrText.toLowerCase().contains(tx.description.toLowerCase());
      if (descMatch) return true;
    }
    return false;
  }

  String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _statementPaymentMethod(ImportedTransaction tx) {
    return tx.sourceFileName.toLowerCase().contains('tng')
        ? 'TNG eWallet'
        : 'Bank Statement';
  }

  List<String> _mergedTags(List<String> current, String sourceFileName) {
    final tags = [...current];
    if (sourceFileName.toLowerCase().contains('tng') && !tags.contains('TNG')) {
      tags.add('TNG');
    }
    if (!tags.contains('MATCHED')) tags.add('MATCHED');
    return tags;
  }

  String _sourceLabel(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('tng')) return 'TNG eWallet';
    if (lower.contains('maybank')) return 'Maybank';
    if (lower.contains('cimb')) return 'CIMB';
    if (lower.contains('public')) return 'Public Bank';
    return 'Bank Statement';
  }

  String _formatLabel(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.csv')) return 'CSV import';
    return 'PDF import';
  }
}
