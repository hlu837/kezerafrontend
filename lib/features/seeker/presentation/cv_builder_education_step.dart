import 'package:flutter/material.dart';

import '../domain/seeker.dart';
import 'cv_builder_shared.dart';

/// CV-03 wizard step 3/6: education entries. Optional, same reasoning as
/// [CvBuilderExperienceStep].
class CvBuilderEducationStep extends StatelessWidget {
  const CvBuilderEducationStep({
    super.key,
    required this.entries,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final List<CvEducation> entries;
  final ValueChanged<List<CvEducation>> onChanged;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  Future<void> _addOrEdit(BuildContext context, {int? editIndex}) async {
    final result = await showDialog<CvEducation>(
      context: context,
      builder: (_) => _EducationEditorDialog(
        initial: editIndex != null ? entries[editIndex] : null,
      ),
    );
    if (result == null) return;
    final updated = List<CvEducation>.of(entries);
    if (editIndex != null) {
      updated[editIndex] = result;
    } else {
      updated.add(result);
    }
    onChanged(updated);
  }

  void _remove(int index) {
    final updated = List<CvEducation>.of(entries)..removeAt(index);
    onChanged(updated);
  }

  String _subtitle(CvEducation e) {
    final range = e.current
        ? '${e.startDate ?? ''} – Present'.trim()
        : [e.startDate, e.endDate].where((s) => s != null && s.isNotEmpty).join(' – ');
    final parts = [
      e.school,
      if (range.isNotEmpty) range,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: CvBuilderSectionCard(
        title: 'Education',
        description: 'Add your schools, colleges, or training programs, most recent first.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isEmpty)
              const CvBuilderEmptyState(
                icon: Icons.school_outlined,
                text: 'No education added yet',
              )
            else
              for (var i = 0; i < entries.length; i++)
                CvBuilderListTile(
                  title: entries[i].degree,
                  subtitle: _subtitle(entries[i]),
                  trailingBadge: entries[i].current ? 'Ongoing' : null,
                  onEdit: () => _addOrEdit(context, editIndex: i),
                  onDelete: () => _remove(i),
                ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addOrEdit(context),
                icon: const Icon(Icons.add),
                label: const Text('Add education'),
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

class _EducationEditorDialog extends StatefulWidget {
  const _EducationEditorDialog({this.initial});

  final CvEducation? initial;

  @override
  State<_EducationEditorDialog> createState() => _EducationEditorDialogState();
}

class _EducationEditorDialogState extends State<_EducationEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _school;
  late final TextEditingController _degree;
  late final TextEditingController _fieldOfStudy;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late bool _current;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _school = TextEditingController(text: e?.school ?? '');
    _degree = TextEditingController(text: e?.degree ?? '');
    _fieldOfStudy = TextEditingController(text: e?.fieldOfStudy ?? '');
    _startDate = TextEditingController(text: e?.startDate ?? '');
    _endDate = TextEditingController(text: e?.endDate ?? '');
    _current = e?.current ?? false;
  }

  @override
  void dispose() {
    _school.dispose();
    _degree.dispose();
    _fieldOfStudy.dispose();
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      CvEducation(
        school: _school.text.trim(),
        degree: _degree.text.trim(),
        fieldOfStudy:
            _fieldOfStudy.text.trim().isEmpty ? null : _fieldOfStudy.text.trim(),
        startDate: _startDate.text.trim().isEmpty ? null : _startDate.text.trim(),
        endDate: _current || _endDate.text.trim().isEmpty ? null : _endDate.text.trim(),
        current: _current,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add education' : 'Edit education'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _school,
                  decoration: const InputDecoration(labelText: 'School / institution *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _degree,
                  decoration: const InputDecoration(
                    labelText: 'Degree / certificate *',
                    hintText: 'e.g. Diploma in Accounting',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fieldOfStudy,
                  decoration: const InputDecoration(labelText: 'Field of study'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startDate,
                        decoration: const InputDecoration(
                          labelText: 'Start date',
                          hintText: 'e.g. 2019',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endDate,
                        enabled: !_current,
                        decoration: const InputDecoration(
                          labelText: 'End date',
                          hintText: 'e.g. 2023',
                        ),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: _current,
                  onChanged: (v) => setState(() => _current = v ?? false),
                  title: const Text('I\'m currently studying here'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
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
