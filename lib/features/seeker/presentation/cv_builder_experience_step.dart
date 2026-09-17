import 'package:flutter/material.dart';

import '../domain/seeker.dart';
import 'cv_builder_shared.dart';

/// CV-03 wizard step 2/6: work experience entries.
///
/// Experience is entirely optional — a first-time job seeker with no
/// work history yet can skip straight to Education, so [onNext] is never
/// gated on the list being non-empty.
class CvBuilderExperienceStep extends StatelessWidget {
  const CvBuilderExperienceStep({
    super.key,
    required this.entries,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final List<CvExperience> entries;
  final ValueChanged<List<CvExperience>> onChanged;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  Future<void> _addOrEdit(BuildContext context, {int? editIndex}) async {
    final result = await showDialog<CvExperience>(
      context: context,
      builder: (_) => _ExperienceEditorDialog(
        initial: editIndex != null ? entries[editIndex] : null,
      ),
    );
    if (result == null) return;
    final updated = List<CvExperience>.of(entries);
    if (editIndex != null) {
      updated[editIndex] = result;
    } else {
      updated.add(result);
    }
    onChanged(updated);
  }

  void _remove(int index) {
    final updated = List<CvExperience>.of(entries)..removeAt(index);
    onChanged(updated);
  }

  String _subtitle(CvExperience e) {
    final range = e.current
        ? '${e.startDate ?? ''} – Present'.trim()
        : [e.startDate, e.endDate].where((s) => s != null && s.isNotEmpty).join(' – ');
    final parts = [
      e.company,
      if (range.isNotEmpty) range,
      if (e.location != null && e.location!.isNotEmpty) e.location!,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: CvBuilderSectionCard(
        title: 'Work experience',
        description:
            'Add roles you\'ve held, most recent first. No experience yet? '
            'Skip this step — plenty of employers hire for potential too.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isEmpty)
              const CvBuilderEmptyState(
                icon: Icons.work_outline,
                text: 'No experience added yet',
              )
            else
              for (var i = 0; i < entries.length; i++)
                CvBuilderListTile(
                  title: entries[i].title,
                  subtitle: _subtitle(entries[i]),
                  trailingBadge: entries[i].current ? 'Current' : null,
                  onEdit: () => _addOrEdit(context, editIndex: i),
                  onDelete: () => _remove(i),
                ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addOrEdit(context),
                icon: const Icon(Icons.add),
                label: const Text('Add experience'),
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

class _ExperienceEditorDialog extends StatefulWidget {
  const _ExperienceEditorDialog({this.initial});

  final CvExperience? initial;

  @override
  State<_ExperienceEditorDialog> createState() => _ExperienceEditorDialogState();
}

class _ExperienceEditorDialogState extends State<_ExperienceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _company;
  late final TextEditingController _location;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _description;
  late bool _current;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _title = TextEditingController(text: e?.title ?? '');
    _company = TextEditingController(text: e?.company ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _startDate = TextEditingController(text: e?.startDate ?? '');
    _endDate = TextEditingController(text: e?.endDate ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _current = e?.current ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _location.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      CvExperience(
        title: _title.text.trim(),
        company: _company.text.trim(),
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        startDate: _startDate.text.trim().isEmpty ? null : _startDate.text.trim(),
        endDate: _current || _endDate.text.trim().isEmpty ? null : _endDate.text.trim(),
        current: _current,
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add experience' : 'Edit experience'),
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
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Job title *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _company,
                  decoration: const InputDecoration(labelText: 'Company *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startDate,
                        decoration: const InputDecoration(
                          labelText: 'Start date',
                          hintText: 'e.g. Jan 2022',
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
                          hintText: 'e.g. Mar 2024',
                        ),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: _current,
                  onChanged: (v) => setState(() => _current = v ?? false),
                  title: const Text('I currently work here'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What did you do in this role?',
                  ),
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
