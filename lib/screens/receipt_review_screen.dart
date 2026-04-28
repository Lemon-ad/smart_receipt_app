import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/receipt.dart';
import '../providers/receipt_provider.dart';
import '../services/llm_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    this.imagePath,
    this.existingReceipt,
    this.manualEntry = false,
  });

  final String? imagePath;
  final Receipt? existingReceipt;
  final bool manualEntry;

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _payment = TextEditingController();
  final _tags = TextEditingController();
  final _raw = TextEditingController();
  DateTime _date = DateTime.now();
  String _type = 'Personal';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[Review] initState existing=${widget.existingReceipt != null} manual=${widget.manualEntry} imagePath=${widget.imagePath}',
    );
    final existing = widget.existingReceipt;
    if (existing != null) {
      _merchant.text = existing.merchantName;
      _amount.text = existing.totalAmount.toStringAsFixed(2);
      _category.text = existing.category;
      _payment.text = existing.paymentMethod;
      _tags.text = existing.tags.join(', ');
      _raw.text = existing.rawOcrText;
      _date = existing.date;
      _type = existing.type;
      _loading = false;
    } else if (widget.manualEntry || widget.imagePath == null) {
      _loading = false;
    } else {
      _process();
    }
  }

  Future<void> _process() async {
    setState(() => _loading = true);
    try {
      debugPrint('[Review] Starting OCR for imagePath=${widget.imagePath}');
      final raw = await OcrService().extractText(widget.imagePath ?? '');
      debugPrint('[Review] OCR complete. rawLength=${raw.length}');
      final parsed = await LlmService().parseReceipt(raw);
      debugPrint(
        '[Review] Parse complete. merchant=${parsed.merchantName} amount=${parsed.totalAmount} category=${parsed.category}',
      );
      _raw.text = raw;
      _merchant.text = parsed.merchantName;
      _amount.text = parsed.totalAmount.toStringAsFixed(2);
      _category.text = parsed.category;
      _payment.text = parsed.paymentMethod;
      _date = parsed.date;
    } catch (error) {
      debugPrint('[Review] Extraction failed: $error');
      _error = 'Extraction failed. You can still enter the fields manually.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingReceipt != null
              ? 'Edit Receipt'
              : widget.manualEntry
              ? 'Add Receipt Manually'
              : 'Review Extraction',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.rose),
              ),
            ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receipt preview',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 210,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.panel2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      widget.imagePath != null &&
                          File(widget.imagePath!).existsSync()
                      ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.receipt_long,
                              size: 58,
                              color: AppTheme.muted,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Manual entry',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Field(controller: _merchant, label: 'Merchant name'),
          _Field(
            controller: _amount,
            label: 'Total amount',
            keyboardType: TextInputType.number,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Receipt date'),
            subtitle: Text(
              _date.toIso8601String().substring(0, 10),
              style: const TextStyle(color: AppTheme.muted),
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          _Field(controller: _category, label: 'Category suggestion'),
          _Field(controller: _payment, label: 'Payment method'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Personal',
                label: Text('Personal'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: 'Business',
                label: Text('Business'),
                icon: Icon(Icons.work_outline),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 12),
          _Field(controller: _tags, label: 'Tags, comma separated'),
          _Field(controller: _raw, label: 'Raw OCR text', maxLines: 6),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Receipt'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final now = DateTime.now();
    final existing = widget.existingReceipt;
    final receipt = Receipt(
      id: existing?.id ?? const Uuid().v4(),
      merchantName: _merchant.text.trim().isEmpty
          ? 'Unknown Merchant'
          : _merchant.text.trim(),
      date: _date,
      totalAmount: double.tryParse(_amount.text.trim()) ?? 0,
      currency: 'MYR',
      category: _category.text.trim().isEmpty
          ? 'Uncategorized'
          : _category.text.trim(),
      type: _type,
      paymentMethod: _payment.text.trim().isEmpty
          ? 'Unknown'
          : _payment.text.trim(),
      tags: _tags.text
          .split(',')
          .map((tag) => tag.trim().toUpperCase())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      imagePath: widget.imagePath ?? existing?.imagePath,
      rawOcrText: _raw.text,
      sourceType: existing?.sourceType ?? 'receipt',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      items: existing?.items ?? const [],
    );
    debugPrint(
      '[Review] Saving receipt id=${receipt.id} merchant=${receipt.merchantName} amount=${receipt.totalAmount} source=${receipt.sourceType}',
    );
    try {
      await ref.read(receiptsProvider.notifier).save(receipt);
      debugPrint('[Review] Save success for receipt id=${receipt.id}');
    } catch (error) {
      debugPrint('[Review] Save failed for receipt id=${receipt.id}: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save receipt: $error')),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
