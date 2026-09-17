import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/seeker.dart';
import 'seeker_profile_provider.dart';

/// CV-02: shown right after a seeker uploads a CV via
/// `SeekerDashboardScreen`'s "CV / Resume" upload row.
///
/// `POST /seekers/upload` already parses the CV and merges whatever it
/// found straight into the profile (skills are unioned in; city/bio are
/// only set if they were previously empty — see
/// `seeker.service.js#handleUpload`), so by the time this screen opens the
/// save has *already happened*. This screen isn't a "confirm before
/// saving" step — it's "here's what changed, review/correct it now, then
/// we save the correction" — which is why it diffs [before] vs [after]
/// rather than holding back the initial merge.
///
/// Pushed with a plain [Navigator] (fullscreen dialog) rather than a
/// go_router route: it's a one-off follow-up to an action, not a nav
/// destination someone would deep-link to or reach from the shell's nav
/// bar.
class CvReviewScreen extends ConsumerStatefulWidget {
  const CvReviewScreen({super.key, required this.before, required this.after});

  /// The seeker's profile immediately before the CV upload.
  final Seeker before;

  /// The seeker's profile as returned by the upload call, i.e. after the
  /// backend's auto-fill merge already applied.
  final Seeker after;

  @override
  ConsumerState<CvReviewScreen> createState() => _CvReviewScreenState();
}

class _CvReviewScreenState extends ConsumerState<CvReviewScreen> {
  late List<String> _skills;
  late final Set<String> _autofilledSkills;
  late final TextEditingController _cityController;
  late final TextEditingController _bioController;
  late final TextEditingController _skillFieldController;
  late final bool _cityAutofilled;
  late final bool _bioAutofilled;

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final beforeSkills = widget.before.skills.map((s) => s.toLowerCase()).toSet();
    _skills = List.of(widget.after.skills);
    _autofilledSkills = widget.after.skills
        .where((s) => !beforeSkills.contains(s.toLowerCase()))
        .toSet();

    _cityAutofilled = (widget.before.city == null || widget.before.city!.isEmpty) &&
        widget.after.city != null &&
        widget.after.city!.isNotEmpty;
    _bioAutofilled = (widget.before.bio == null || widget.before.bio!.isEmpty) &&
        widget.after.bio != null &&
        widget.after.bio!.isNotEmpty;

    _cityController = TextEditingController(text: widget.after.city ?? '');
    _bioController = TextEditingController(text: widget.after.bio ?? '');
    _skillFieldController = TextEditingController();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _bioController.dispose();
    _skillFieldController.dispose();
    super.dispose();
  }

  bool get _hasAnyAutofill =>
      _autofilledSkills.isNotEmpty || _cityAutofilled || _bioAutofilled;

  void _addSkill() {
    final value = _skillFieldController.text.trim();
    if (value.isEmpty) return;
    final alreadyPresent =
        _skills.any((s) => s.toLowerCase() == value.toLowerCase());
    if (!alreadyPresent) {
      setState(() => _skills = [..._skills, value]);
    }
    _skillFieldController.clear();
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills = _skills.where((s) => s != skill).toList();
      _autofilledSkills.remove(skill);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(myProfileProvider.notifier).updateProfile(
            skills: _skills,
            city: _cityController.text.trim(),
            bio: _bioController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review your CV details'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Not now',
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IntroBanner(hasAnyAutofill: _hasAnyAutofill),
              const SizedBox(height: 24),
              Text('Skills', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Skills we picked up from your CV are marked "From CV" — '
                'remove anything that\'s wrong, or add what we missed.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _skillFieldController,
                decoration: InputDecoration(
                  hintText: 'Add a skill',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add skill',
                    onPressed: _addSkill,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSkill(),
              ),
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in _skills)
                      _SkillChip(
                        label: skill,
                        fromCv: _autofilledSkills.contains(skill),
                        onDeleted: () => _removeSkill(skill),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              _FieldLabel(text: 'City', autofilled: _cityAutofilled),
              const SizedBox(height: 8),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Addis Ababa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              _FieldLabel(text: 'Bio', autofilled: _bioAutofilled),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  hintText: 'A couple of sentences about your experience',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                maxLength: 5000,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.hasAnyAutofill});

  final bool hasAnyAutofill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasAnyAutofill ? Icons.auto_awesome : Icons.info_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasAnyAutofill
                  ? "We've filled in what we could read from your CV. "
                      "Take a look and fix anything that's off before you save."
                  : "We couldn't pick up much from that CV automatically — "
                      'no problem, just fill in your skills, city, and bio below.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.autofilled});

  final String text;
  final bool autofilled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(text, style: theme.textTheme.titleMedium),
        if (autofilled) ...[
          const SizedBox(width: 8),
          const _FromCvBadge(),
        ],
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.label,
    required this.fromCv,
    required this.onDeleted,
  });

  final String label;
  final bool fromCv;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputChip(
      label: Text(label),
      avatar: fromCv
          ? Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary)
          : null,
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
      backgroundColor: fromCv
          ? theme.colorScheme.primaryContainer.withOpacity(0.5)
          : null,
    );
  }
}

class _FromCvBadge extends StatelessWidget {
  const _FromCvBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'From CV',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
