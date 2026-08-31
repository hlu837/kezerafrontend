import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'cv_builder_shared.dart';

/// CV-03 wizard step 1/6: name, city, professional summary, and skills.
///
/// These four fields already exist on the seeker's regular profile
/// (`fullName`/`city`/`bio`/`skills` — see `seeker.dart`), so this step
/// just edits them in place; [CvBuilderScreen] saves them back through
/// the normal `PATCH /seekers/me` profile endpoint rather than the CV
/// builder's own endpoints, keeping "my profile" as the single source of
/// truth for identity fields instead of forking a second copy.
class CvBuilderPersonalStep extends StatefulWidget {
  const CvBuilderPersonalStep({
    super.key,
    required this.fullNameController,
    required this.cityController,
    required this.summaryController,
    required this.skills,
    required this.onSkillsChanged,
    required this.onBack,
    required this.onNext,
  });

  final TextEditingController fullNameController;
  final TextEditingController cityController;
  final TextEditingController summaryController;
  final List<String> skills;
  final ValueChanged<List<String>> onSkillsChanged;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  State<CvBuilderPersonalStep> createState() => _CvBuilderPersonalStepState();
}

class _CvBuilderPersonalStepState extends State<CvBuilderPersonalStep> {
  final _formKey = GlobalKey<FormState>();
  final _skillFieldController = TextEditingController();

  @override
  void dispose() {
    _skillFieldController.dispose();
    super.dispose();
  }

  void _addSkill() {
    final value = _skillFieldController.text.trim();
    if (value.isEmpty) return;
    final alreadyPresent =
        widget.skills.any((s) => s.toLowerCase() == value.toLowerCase());
    if (!alreadyPresent) {
      widget.onSkillsChanged([...widget.skills, value]);
    }
    _skillFieldController.clear();
  }

  void _removeSkill(String skill) {
    widget.onSkillsChanged(widget.skills.where((s) => s != skill).toList());
  }

  void _handleNext() {
    if (_formKey.currentState?.validate() != true) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Form(
        key: _formKey,
        child: CvBuilderSectionCard(
          title: 'Let\'s start with the basics',
          description:
              'This goes at the top of your CV — make sure it\'s accurate '
              'and up to date.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Full name', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: widget.fullNameController,
                decoration: const InputDecoration(hintText: 'e.g. Abebe Kebede'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 20),
              const Text('City', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: widget.cityController,
                decoration: const InputDecoration(hintText: 'e.g. Addis Ababa'),
              ),
              const SizedBox(height: 20),
              const Text('Professional summary',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'A couple of sentences introducing yourself to an employer.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: widget.summaryController,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Reliable customer service professional with 3 years\' '
                      'experience in fast-paced retail environments...',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Skills', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _skillFieldController,
                decoration: InputDecoration(
                  hintText: 'Add a skill and press enter',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add skill',
                    onPressed: _addSkill,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSkill(),
              ),
              if (widget.skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in widget.skills)
                      InputChip(
                        label: Text(skill),
                        onDeleted: () => _removeSkill(skill),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              CvBuilderNavBar(onBack: widget.onBack, onNext: _handleNext),
            ],
          ),
        ),
      ),
    );
  }
}
