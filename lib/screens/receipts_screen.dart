import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import '../providers/receipt_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/receipt_tile.dart';
import '../widgets/section_header.dart';
import 'receipt_detail_screen.dart';
import 'receipt_review_screen.dart';
import 'statement_import_screen.dart';

class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  String _query = '';
  String _chip = 'All';
  String _summaryPeriod = 'Monthly';
  final _chips = const ['All', 'Personal', 'Business', 'This Month', 'Travel'];
  final _summaryPeriods = const ['Weekly', 'Monthly', 'Yearly'];
  final Set<String> _selected = {};
  final Set<String> _filterTags = {};

  bool get _isSelecting => _selected.isNotEmpty;

  void _enterSelection(String id) {
    setState(() => _selected.add(id));
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

  void _clearSelection() => setState(_selected.clear);

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete receipts?'),
        content: Text('Permanently delete $count receipt${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.rose)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(receiptsProvider.notifier).removeMany(_selected.toList());
      if (mounted) {
        setState(_selected.clear);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count receipt${count == 1 ? '' : 's'} deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptsProvider);
    final filtered = _applyFilters(receipts);
    final prefs = ref.watch(preferencesProvider);
    final dateFormat = prefs.dateFormat;
    final currency = prefs.currency;
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final startOfNextWeek = startOfWeek.add(const Duration(days: 7));
    final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));
    final startOfYear = DateTime(now.year);
    final startOfNextYear = DateTime(now.year + 1);
    final startOfLastYear = DateTime(now.year - 1);
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
    final thisWeek = receipts
        .where(
          (r) =>
              !r.date.isBefore(startOfWeek) && r.date.isBefore(startOfNextWeek),
        )
        .toList();
    final lastWeek = receipts
        .where(
          (r) =>
              !r.date.isBefore(startOfLastWeek) && r.date.isBefore(startOfWeek),
        )
        .toList();
    final total = thisMonth.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final previous = lastMonth.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final weeklyTotal = thisWeek.fold<double>(
      0,
      (sum, r) => sum + r.totalAmount,
    );
    final previousWeek = lastWeek.fold<double>(
      0,
      (sum, r) => sum + r.totalAmount,
    );
    final thisYear = receipts
        .where(
          (r) =>
              !r.date.isBefore(startOfYear) && r.date.isBefore(startOfNextYear),
        )
        .toList();
    final lastYear = receipts
        .where(
          (r) =>
              !r.date.isBefore(startOfLastYear) && r.date.isBefore(startOfYear),
        )
        .toList();
    final yearlyTotal = thisYear.fold<double>(
      0,
      (sum, r) => sum + r.totalAmount,
    );
    final previousYear = lastYear.fold<double>(
      0,
      (sum, r) => sum + r.totalAmount,
    );
    final diff = previous == 0 ? 100 : ((total - previous) / previous) * 100;
    final weeklyDiff = previousWeek == 0
        ? 100
        : ((weeklyTotal - previousWeek) / previousWeek) * 100;
    final yearlyDiff = previousYear == 0
        ? 100
        : ((yearlyTotal - previousYear) / previousYear) * 100;
    final summary = switch (_summaryPeriod) {
      'Weekly' => (
        title: 'Weekly spending',
        amount: weeklyTotal,
        diff: weeklyDiff,
        compareLabel: 'vs last week',
        count: thisWeek.length,
      ),
      'Yearly' => (
        title: 'Yearly spending',
        amount: yearlyTotal,
        diff: yearlyDiff,
        compareLabel: 'vs last year',
        count: thisYear.length,
      ),
      _ => (
        title: 'Monthly spending',
        amount: total,
        diff: diff,
        compareLabel: 'vs last month',
        count: thisMonth.length,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: _isSelecting
            ? Text(
                '${_selected.length} selected',
                style: const TextStyle(fontWeight: FontWeight.w900),
              )
            : const Text(
                'Receipts',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_isSelecting) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.rose),
              tooltip: 'Delete selected',
              onPressed: _deleteSelected,
            ),
            const SizedBox(width: 8),
          ] else ...[
            SoftIconButton(
              icon: Icons.edit_note,
              tooltip: 'Add manually',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReceiptReviewScreen(manualEntry: true),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SoftIconButton(
              icon: Icons.upload_file,
              tooltip: 'Import statement',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatementImportScreen()),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
          Text(
            monthLabel(now, format: dateFormat),
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryCard(
            title: summary.title,
            amount: money(summary.amount, currency: currency),
            primaryMetricLabel: summary.compareLabel,
            primaryMetricValue:
                '${summary.diff >= 0 ? '+' : ''}${summary.diff.toStringAsFixed(1)}%',
            secondaryMetricLabel: 'receipts',
            secondaryMetricValue: '${summary.count}',
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _summaryPeriod,
                dropdownColor: AppTheme.panel2,
                borderRadius: BorderRadius.circular(12),
                style: const TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w700,
                ),
                iconEnabledColor: AppTheme.muted,
                items: _summaryPeriods
                    .map(
                      (period) => DropdownMenuItem<String>(
                        value: period,
                        child: Text(period),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _summaryPeriod = value);
                },
              ),
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
                tooltip: 'Filter by tags',
                onPressed: _showTagFilter,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_filterTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._filterTags.map(
                    (tag) => Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _filterTags.remove(tag)),
                      backgroundColor: AppTheme.accent.withValues(alpha: .18),
                      labelStyle: const TextStyle(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ActionChip(
                    label: const Text('Clear filters'),
                    onPressed: () => setState(_filterTags.clear),
                    backgroundColor: AppTheme.panel2,
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            children: _chips.map((chip) {
              return ChoiceChip(
                label: Text(chip),
                selected: _chip == chip,
                onSelected: (_) => setState(() {
                  _chip = chip;
                  _selected.clear();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SectionHeader('${filtered.length} receipts'),
          const SizedBox(height: 8),
          ..._grouped(filtered, dateFormat).entries.map(
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
                      isSelectionMode: _isSelecting,
                      isSelected: _selected.contains(receipt.id),
                      onTap: _isSelecting
                          ? () => _toggleSelection(receipt.id)
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReceiptDetailScreen(receiptId: receipt.id),
                                ),
                              ),
                      onLongPress: _isSelecting
                          ? null
                          : () => _enterSelection(receipt.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _showTagFilter() async {
    final tags = ref.read(tagsProvider);
    if (tags.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tags available.')),
        );
      }
      return;
    }
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TagFilterSheet(
        allTags: tags,
        selected: _filterTags,
      ),
    );
    if (result != null) {
      setState(() => _filterTags..clear()..addAll(result));
    }
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
      final matchesTags = _filterTags.isEmpty ||
          receipt.tags.any((tag) => _filterTags.contains(tag));
      return matchesSearch && matchesChip && matchesTags;
    }).toList();
  }

  Map<String, List<Receipt>> _grouped(List<Receipt> receipts, String dateFormat) {
    final grouped = <String, List<Receipt>>{};
    for (final receipt in receipts) {
      grouped.putIfAbsent(monthLabel(receipt.date, format: dateFormat), () => []).add(receipt);
    }
    return grouped;
  }
}

class _TagFilterSheet extends StatefulWidget {
  const _TagFilterSheet({required this.allTags, required this.selected});

  final List<String> allTags;
  final Set<String> selected;

  @override
  State<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<_TagFilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter by tags',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.allTags.map((tag) {
                final isSelected = _selected.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selected.add(tag);
                      } else {
                        _selected.remove(tag);
                      }
                    });
                  },
                  selectedColor: AppTheme.accent.withValues(alpha: .24),
                  checkmarkColor: AppTheme.accent,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.primaryMetricLabel,
    required this.primaryMetricValue,
    required this.secondaryMetricLabel,
    required this.secondaryMetricValue,
    this.trailing,
  });

  final String title;
  final String amount;
  final String primaryMetricLabel;
  final String primaryMetricValue;
  final String secondaryMetricLabel;
  final String secondaryMetricValue;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
              if (trailing != null) ...[trailing!],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: primaryMetricLabel, value: primaryMetricValue),
              const SizedBox(width: 12),
              _Metric(label: secondaryMetricLabel, value: secondaryMetricValue),
            ],
          ),
        ],
      ),
    );
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
