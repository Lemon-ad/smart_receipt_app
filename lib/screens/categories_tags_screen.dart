import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';

class CategoriesTagsScreen extends ConsumerStatefulWidget {
  const CategoriesTagsScreen({super.key});

  @override
  ConsumerState<CategoriesTagsScreen> createState() =>
      _CategoriesTagsScreenState();
}

class _CategoriesTagsScreenState extends ConsumerState<CategoriesTagsScreen> {
  final _categoryController = TextEditingController();
  final _tagController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final tags = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories & Tags',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          const SectionHeader('Categories'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddRow(
                  controller: _categoryController,
                  hint: 'New category',
                  onAdd: _addCategory,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map(
                        (c) => Chip(
                          label: Text(c),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeCategory(c),
                          backgroundColor: AppTheme.accent.withValues(
                            alpha: .18,
                          ),
                          labelStyle: const TextStyle(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Tags'),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddRow(
                  controller: _tagController,
                  hint: 'New tag',
                  onAdd: _addTag,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map(
                        (t) => Chip(
                          label: Text(t),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(t),
                          backgroundColor: AppTheme.cyan.withValues(
                            alpha: .18,
                          ),
                          labelStyle: const TextStyle(
                            color: AppTheme.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    final value = _categoryController.text.trim();
    if (value.isEmpty) return;
    try {
      await ref.read(categoriesProvider.notifier).add(value);
      _categoryController.clear();
    } on StateError catch (e) {
      _show(e.message);
    }
  }

  Future<void> _removeCategory(String category) async {
    await ref.read(categoriesProvider.notifier).remove(category);
  }

  Future<void> _addTag() async {
    final value = _tagController.text.trim();
    if (value.isEmpty) return;
    try {
      await ref.read(tagsProvider.notifier).add(value);
      _tagController.clear();
    } on StateError catch (e) {
      _show(e.message);
    }
  }

  Future<void> _removeTag(String tag) async {
    await ref.read(tagsProvider.notifier).remove(tag);
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.controller,
    required this.hint,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
