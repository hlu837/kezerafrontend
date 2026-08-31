import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/seeker.dart';
import 'cv_builder_shared.dart';

/// CV-03 wizard step 6/6: a read-only summary of everything that's about
/// to go into the PDF, plus the "Generate CV" action.
///
/// Purely presentational — [CvBuilderScreen] owns the actual generate
/// call (it needs the profile notifier) and passes the outcome down via
/// [isGenerating]/[errorMessage]/[generatedCvUrl].
class CvBuilderReviewStep extends StatelessWidget {
  const CvBuilderReviewStep({
    super.key,
    required this.fullName,
    required this.city,
    required this.summary,
    required this.skills,
    required this.experience,
    required this.education,
    required this.languages,
    required this.template,
    required this.onBack,
    required this.onGenerate,
    required this.onEditStep,
    required this.isGenerating,
    this.errorMessage,
    this.generatedCvUrl,
    required this.onViewCv,
    required this.onDone,
  });

  final String fullName;
  final String city;
  final String summary;
  final List<String> skills;
  final List<CvExperience> experience;
  final List<CvEducation> education;
  final List<CvLanguage> languages;
  final CvTemplate template;
  final VoidCallback? onBack;
  final VoidCallback onGenerate;
  final ValueChanged<CvBuilderStep> onEditStep;
  final bool isGenerating;
  final String? errorMessage;
  final String? generatedCvUrl;
  final VoidCallback onViewCv;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (generatedCvUrl != null) {
      return _SuccessView(onViewCv: onViewCv, onDone: onDone);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: CvBuilderSectionCard(
        title: 'Review & generate',
        description: 'Here\'s everything that will go into your CV. Looks good?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewSection(
              title: 'Personal details',
              onEdit: () => onEditStep(CvBuilderStep.personal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName.isEmpty ? 'Not set' : fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (city.isNotEmpty) Text(city, style: const TextStyle(color: AppColors.inkMuted)),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(summary, style: const TextStyle(color: AppColors.inkMuted, height: 1.4)),
                  ],
                  if (skills.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in skills)
                          Chip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _ReviewSection(
              title: 'Experience (${experience.length})',
              onEdit: () => onEditStep(CvBuilderStep.experience),
              child: experience.isEmpty
                  ? const Text('None added', style: TextStyle(color: AppColors.inkFaint))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in experience)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('${e.title} · ${e.company}'),
                          ),
                      ],
                    ),
            ),
            _ReviewSection(
              title: 'Education (${education.length})',
              onEdit: () => onEditStep(CvBuilderStep.education),
              child: education.isEmpty
                  ? const Text('None added', style: TextStyle(color: AppColors.inkFaint))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in education)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('${e.degree} · ${e.school}'),
                          ),
                      ],
                    ),
            ),
            _ReviewSection(
              title: 'Languages (${languages.length})',
              onEdit: () => onEditStep(CvBuilderStep.languages),
              child: languages.isEmpty
                  ? const Text('None added', style: TextStyle(color: AppColors.inkFaint))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final l in languages)
                          Chip(
                            label: Text('${l.name} · ${l.level.label}',
                                style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
            ),
            _ReviewSection(
              title: 'Template',
              onEdit: () => onEditStep(CvBuilderStep.template),
              child: Text(
                switch (template) {
                  CvTemplate.classic => 'Classic',
                  CvTemplate.modern => 'Modern',
                  CvTemplate.minimal => 'Minimal',
                },
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            CvBuilderNavBar(
              onBack: onBack,
              onNext: onGenerate,
              nextLabel: 'Generate CV',
              isNextLoading: isGenerating,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.onEdit, required this.child});

  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onViewCv, required this.onDone});

  final VoidCallback onViewCv;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.greenSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.greenDark, size: 36),
              ),
              const SizedBox(height: 20),
              Text('Your CV is ready!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              const Text(
                'We\'ve generated your CV and saved it to your profile. Employers '
                'and agencies will see it when they view your candidate profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewCv,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('View my CV'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Go to dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
