import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/receipt.dart';
import '../providers/receipt_provider.dart';
import '../providers/settings_provider.dart';
import '../services/llm_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
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
  final _tax = TextEditingController();
  final _serviceCharge = TextEditingController();
  DateTime _date = DateTime.now();
  String _type = 'Personal';
  final List<ReceiptItem> _items = [];
  String? _currentImagePath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[Review] initState existing=${widget.existingReceipt != null} manual=${widget.manualEntry} imagePath=${widget.imagePath}',
    );
    final existing = widget.existingReceipt;
    _currentImagePath = widget.imagePath ?? existing?.imagePath;
    if (existing != null) {
      _merchant.text = existing.merchantName;
      _amount.text = existing.totalAmount.toStringAsFixed(2);
      _category.text = existing.category;
      _payment.text = existing.paymentMethod;
      _tags.text = existing.tags.join(', ');
      _raw.text = existing.rawOcrText;
      _date = existing.date;
      _type = existing.type;
      _tax.text = existing.taxAmount.toStringAsFixed(2);
      _serviceCharge.text = existing.serviceChargeAmount.toStringAsFixed(2);
      _items.addAll(existing.items);
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
      debugPrint('[Review] Starting OCR for imagePath=$_currentImagePath');
      final raw = await OcrService().extractText(_currentImagePath ?? '');
      debugPrint('[Review] OCR complete. rawLength=${raw.length}');
      final parsed = await LlmService().parseReceipt(raw);
      debugPrint(
        '[Review] Parse complete. merchant=${parsed.merchantName} amount=${parsed.totalAmount} category=${parsed.category} tax=${parsed.taxAmount} svc=${parsed.serviceChargeAmount}',
      );
      _raw.text = raw;
      _merchant.text = parsed.merchantName;
      _amount.text = parsed.totalAmount.toStringAsFixed(2);
      _category.text = parsed.category;
      _payment.text = parsed.paymentMethod;
      _tax.text = parsed.taxAmount.toStringAsFixed(2);
      _serviceCharge.text = parsed.serviceChargeAmount.toStringAsFixed(2);
      _date = parsed.date;
      _items
        ..clear()
        ..addAll(parsed.items);
    } catch (error) {
      debugPrint('[Review] Extraction failed: $error');
      _error = 'Extraction failed. You can still enter the fields manually.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _replaceImage(ImageSource source) async {
    Navigator.of(context).pop();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    final dir = await getApplicationSupportDirectory();
    final ext = picked.path.split('.').lastOrNull ?? 'jpg';
    final newPath =
        '${dir.path}/receipt_scan_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(picked.path).copy(newPath);

    setState(() {
      _currentImagePath = newPath;
      _loading = true;
      _error = null;
    });
    await _process();
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => _replaceImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => _replaceImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        _currentImagePath != null && File(_currentImagePath!).existsSync();
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
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    height: 210,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.panel2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              hasImage
                              ? Image.file(
                                  File(_currentImagePath!),
                                  fit: BoxFit.cover,
                                )
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
                                      'Tap to add image',
                                      style: TextStyle(color: AppTheme.muted),
                                    ),
                                  ],
                                ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Replace',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
          _buildItemsCard(),
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
    final prefs = ref.read(preferencesProvider);
    final receipt = Receipt(
      id: existing?.id ?? const Uuid().v4(),
      merchantName: _merchant.text.trim().isEmpty
          ? 'Unknown Merchant'
          : _merchant.text.trim(),
      date: _date,
      totalAmount: double.tryParse(_amount.text.trim()) ?? 0,
      currency: prefs.currency,
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
      imagePath: _currentImagePath ?? existing?.imagePath,
      rawOcrText: _raw.text,
      sourceType: existing?.sourceType ?? 'receipt',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      items: List.unmodifiable(_items),
      taxAmount: double.tryParse(_tax.text.trim()) ?? 0,
      serviceChargeAmount: double.tryParse(_serviceCharge.text.trim()) ?? 0,
    );
    debugPrint(
      '[Review] Saving receipt id=${receipt.id} merchant=${receipt.merchantName} amount=${receipt.totalAmount} tax=${receipt.taxAmount} svc=${receipt.serviceChargeAmount} source=${receipt.sourceType}',
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

  Widget _buildItemsCard() {
    final currency = ref.read(preferencesProvider).currency;
    final itemsSum = _items.fold(0.0, (sum, i) => sum + i.totalPrice);
    final tax = double.tryParse(_tax.text.trim()) ?? 0;
    final serviceCharge = double.tryParse(_serviceCharge.text.trim()) ?? 0;
    final calculated = itemsSum + tax + serviceCharge;
    final entered = double.tryParse(_amount.text.trim()) ?? 0;
    final matches = (calculated - entered).abs() < 0.01;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${_items.length} item${_items.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Text(
              'No line items. Tap + to add.',
              style: TextStyle(color: AppTheme.muted),
            )
          else
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(item.name),
                subtitle: Text(
                  '${item.quantity == item.quantity.truncateToDouble() ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2)}x @ ${money(item.unitPrice, currency: currency)} = ${money(item.totalPrice, currency: currency)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _editItem(index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: AppTheme.rose,
                      ),
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
          const Divider(),
          _BreakdownRow(label: 'Subtotal', value: itemsSum, currency: currency),
          _BreakdownRow(
            label: 'Tax (SST/GST)',
            value: tax,
            currency: currency,
            controller: _tax,
            onChanged: () => setState(() {}),
          ),
          _BreakdownRow(
            label: 'Service charge',
            value: serviceCharge,
            currency: currency,
            controller: _serviceCharge,
            onChanged: () => setState(() {}),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Calculated total'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(calculated, currency: currency),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: matches ? AppTheme.green : AppTheme.rose,
                    ),
                  ),
                  if (!matches)
                    IconButton(
                      icon: const Icon(Icons.sync, size: 18),
                      tooltip: 'Sync total from breakdown',
                      onPressed: () => setState(
                        () => _amount.text = calculated.toStringAsFixed(2),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final item = await showDialog<ReceiptItem>(
      context: context,
      builder: (_) => const _ItemDialog(),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _editItem(int index) async {
    final item = await showDialog<ReceiptItem>(
      context: context,
      builder: (_) => _ItemDialog(item: _items[index]),
    );
    if (item != null) setState(() => _items[index] = item);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _category.dispose();
    _payment.dispose();
    _tags.dispose();
    _raw.dispose();
    _tax.dispose();
    _serviceCharge.dispose();
    super.dispose();
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.currency,
    this.controller,
    this.onChanged,
  });

  final String label;
  final double value;
  final String currency;
  final TextEditingController? controller;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(label, style: const TextStyle(color: AppTheme.muted)),
            ),
            Expanded(
              flex: 3,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                  hintText: '0.00',
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => onChanged?.call(),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted)),
          Text(
            money(value, currency: currency),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({this.item});
  final ReceiptItem? item;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _name.text = widget.item!.name;
      _quantity.text = widget.item!.quantity.toString();
      _unitPrice.text = widget.item!.unitPrice.toStringAsFixed(2);
    } else {
      _quantity.text = '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          TextField(
            controller: _quantity,
            decoration: const InputDecoration(labelText: 'Quantity'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: _unitPrice,
            decoration: const InputDecoration(labelText: 'Unit price (RM)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final quantity = double.tryParse(_quantity.text) ?? 1;
            final unitPrice = double.tryParse(_unitPrice.text) ?? 0;
            Navigator.pop(
              context,
              ReceiptItem(
                name: _name.text.trim().isEmpty ? 'Item' : _name.text.trim(),
                quantity: quantity,
                unitPrice: unitPrice,
                totalPrice: quantity * unitPrice,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
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
