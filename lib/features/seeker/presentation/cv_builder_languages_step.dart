import 'package:flutter/material.dart';

import '../domain/seeker.dart';
import 'cv_builder_shared.dart';

/// CV-03 wizard step 4/6: languages spoken + self-rated proficiency.
/// Optional, same reasoning as the experience/education steps.
class CvBuilderLanguagesStep extends StatelessWidget {
  const CvBuilderLanguagesStep({
    super.key,
    required this.entries,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final List<CvLanguage> entries;
  final ValueChanged<List<CvLanguage>> onChanged;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  Future<void> _addOrEdit(BuildContext context, {int? editIndex}) async {
    final result = await showDialog<CvLanguage>(
      context: context,
      builder: (_) => _LanguageEditorDialog(
        initial: editIndex != null ? entries[editIndex] : null,
      ),
    );
    if (result == null) return;
    final updated = List<CvLanguage>.of(entries);
    if (editIndex != null) {
      updated[editIndex] = result;
    } else {
      updated.add(result);
    }
    onChanged(updated);
  }

  void _remove(int index) {
    final updated = List<CvLanguage>.of(entries)..removeAt(index);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: CvBuilderSectionCard(
        title: 'Languages',
        description: 'Let employers know which languages you speak and how well.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isEmpty)
              const CvBuilderEmptyState(
                icon: Icons.language_outlined,
                text: 'No languages added yet',
              )
            else
              for (var i = 0; i < entries.length; i++)
                CvBuilderListTile(
                  title: entries[i].name,
                  subtitle: entries[i].level.label,
                  onEdit: () => _addOrEdit(context, editIndex: i),
                  onDelete: () => _remove(i),
                ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addOrEdit(context),
                icon: const Icon(Icons.add),
                label: const Text('Add language'),
              ),
            ),
            const SizedBox(height: 32),
            CvBuilderNavBar(onBack: onBack, onNext: onNext),
          ],
        ),
      ),
    );
  }
}

class _LanguageEditorDialog extends StatefulWidget {
  const _LanguageEditorDialog({this.initial});

  final CvLanguage? initial;

  @override
  State<_LanguageEditorDialog> createState() => _LanguageEditorDialogState();
}

class _LanguageEditorDialogState extends State<_LanguageEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late CvLanguageLevel _level;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _level = widget.initial?.level ?? CvLanguageLevel.conversational;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context)
        .pop(CvLanguage(name: _name.text.trim(), level: _level));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add language' : 'Edit language'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Language *',
                  hintText: 'e.g. Amharic',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Proficiency', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final level in CvLanguageLevel.values)
                    ChoiceChip(
                      label: Text(level.label),
                      selected: _level == level,
                      onSelected: (_) => setState(() => _level = level),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
