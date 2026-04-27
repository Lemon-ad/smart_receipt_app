import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import '../providers/receipt_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/receipt_tile.dart';
import '../widgets/section_header.dart';
import 'receipt_detail_screen.dart';
import 'statement_import_screen.dart';

class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  String _query = '';
  String _chip = 'All';
  final _chips = const ['All', 'Personal', 'Business', 'This Month', 'Travel'];

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptsProvider);
    final filtered = _applyFilters(receipts);
    final now = DateTime.now();
    final thisMonth = receipts
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .toList();
    final lastMonth = receipts
        .where(
          (r) =>
              r.date.year == DateTime(now.year, now.month - 1).year &&
              r.date.month == DateTime(now.year, now.month - 1).month,
        )
        .toList();
    final total = thisMonth.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final previous = lastMonth.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final diff = previous == 0 ? 100 : ((total - previous) / previous) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Receipts',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          SoftIconButton(
            icon: Icons.upload_file,
            tooltip: 'Import statement',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatementImportScreen()),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Text(
            monthLabel(now),
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly spending',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  money(total),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Metric(
                      label: 'vs last month',
                      value:
                          '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(width: 12),
                    _Metric(label: 'receipts', value: '${thisMonth.length}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search merchants',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SoftIconButton(
                icon: Icons.filter_list,
                tooltip: 'Filter',
                onPressed: () => setState(() => _chip = 'This Month'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _chips.map((chip) {
              return ChoiceChip(
                label: Text(chip),
                selected: _chip == chip,
                onSelected: (_) => setState(() => _chip = chip),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SectionHeader('${filtered.length} receipts'),
          const SizedBox(height: 8),
          ..._grouped(filtered).entries.map(
            (entry) => AppCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  ...entry.value.map(
                    (receipt) => ReceiptTile(
                      receipt: receipt,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiptDetailScreen(receiptId: receipt.id),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Receipt> _applyFilters(List<Receipt> receipts) {
    final now = DateTime.now();
    return receipts.where((receipt) {
      final matchesSearch = receipt.merchantName.toLowerCase().contains(
        _query.toLowerCase(),
      );
      final matchesChip = switch (_chip) {
        'Personal' => receipt.type == 'Personal',
        'Business' => receipt.type == 'Business',
        'This Month' =>
          receipt.date.year == now.year && receipt.date.month == now.month,
        'Travel' =>
          receipt.category == 'Travel' || receipt.tags.contains('TRAVEL'),
        _ => true,
      };
      return matchesSearch && matchesChip;
    }).toList();
  }

  Map<String, List<Receipt>> _grouped(List<Receipt> receipts) {
    final grouped = <String, List<Receipt>>{};
    for (final receipt in receipts) {
      grouped.putIfAbsent(shortDate(receipt.date), () => []).add(receipt);
    }
    return grouped;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.panel2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
