import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/seeker.dart';
import 'cv_builder_shared.dart';

/// CV-03 wizard step 5/6: pick one of the 3 CV templates the backend can
/// render (`src/services/cvGenerator.service.js` — `classic`, `modern`,
/// `minimal`). The thumbnails here are deliberately simplified layout
/// sketches (bars standing in for text lines) rather than literal
/// screenshots of the PDF — cheap to keep in sync as the real templates
/// evolve, and they read fine at this size.
class CvBuilderTemplateStep extends StatelessWidget {
  const CvBuilderTemplateStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final CvTemplate selected;
  final ValueChanged<CvTemplate> onChanged;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  static const _templates = [
    (
      template: CvTemplate.classic,
      title: 'Classic',
      description: 'Traditional single-column layout. Safe, familiar, works everywhere.',
    ),
    (
      template: CvTemplate.modern,
      title: 'Modern',
      description: 'Two-column layout with a bold sidebar for contact info & skills.',
    ),
    (
      template: CvTemplate.minimal,
      title: 'Minimal',
      description: 'Clean and spacious, with a single accent line. Easy to scan.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: CvBuilderSectionCard(
        title: 'Choose a template',
        description:
            'Pick the look of your CV. You can regenerate with a different '
            'template any time from your dashboard.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 520;
                final cards = [
                  for (final t in _templates)
                    _TemplateCard(
                      template: t.template,
                      title: t.title,
                      description: t.description,
                      isSelected: selected == t.template,
                      onTap: () => onChanged(t.template),
                    ),
                ];
                if (!isWide) {
                  return Column(
                    children: [
                      for (final card in cards) ...[
                        card,
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 14),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            CvBuilderNavBar(onBack: onBack, onNext: onNext),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final CvTemplate template;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.green : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 0.72,
              child: _CvTemplateThumbnail(template: template),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? AppColors.green : AppColors.inkFaint,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkMuted, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniature layout sketch of each template. `bar()` stands in for a line
/// of text — proportions are tuned to loosely resemble the real PDF
/// layout produced by the matching branch of
/// `cvGenerator.service.js#renderClassic/renderModern/renderMinimal`.
class _CvTemplateThumbnail extends StatelessWidget {
  const _CvTemplateThumbnail({required this.template});

  final CvTemplate template;

  static Widget _bar({
    double widthFactor = 1,
    double height = 4,
    Color color = const Color(0xFFD8DBDD),
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(10),
      child: switch (template) {
        CvTemplate.classic => _classic(),
        CvTemplate.modern => _modern(),
        CvTemplate.minimal => _minimal(),
      },
    );
  }

  Widget _classic() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 6,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(2)),
        ),
        _bar(widthFactor: 0.5, height: 3, color: AppColors.inkFaint),
        const SizedBox(height: 10),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 8),
        _bar(widthFactor: 0.35, height: 4, color: AppColors.ink),
        _bar(widthFactor: 1),
        _bar(widthFactor: 0.9),
        _bar(widthFactor: 0.7),
        const SizedBox(height: 8),
        _bar(widthFactor: 0.35, height: 4, color: AppColors.ink),
        _bar(widthFactor: 0.95),
        _bar(widthFactor: 0.8),
      ],
    );
  }

  Widget _modern() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 26,
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
              const SizedBox(height: 8),
              _bar(widthFactor: 1, height: 3, color: Colors.white.withOpacity(0.85)),
              _bar(widthFactor: 0.7, height: 3, color: Colors.white.withOpacity(0.85)),
              const SizedBox(height: 6),
              _bar(widthFactor: 1, height: 3, color: Colors.white.withOpacity(0.6)),
              _bar(widthFactor: 0.8, height: 3, color: Colors.white.withOpacity(0.6)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(widthFactor: 0.7, height: 6, color: AppColors.ink),
              const SizedBox(height: 8),
              _bar(widthFactor: 0.4, height: 4, color: AppColors.greenDark),
              _bar(widthFactor: 1),
              _bar(widthFactor: 0.9),
              const SizedBox(height: 8),
              _bar(widthFactor: 0.4, height: 4, color: AppColors.greenDark),
              _bar(widthFactor: 0.95),
              _bar(widthFactor: 0.6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _minimal() {
    return Row(
      children: [
        Container(width: 3, decoration: const BoxDecoration(color: AppColors.green)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(widthFactor: 0.6, height: 6, color: AppColors.ink),
              _bar(widthFactor: 0.4, height: 3, color: AppColors.inkFaint),
              const SizedBox(height: 14),
              _bar(widthFactor: 0.3, height: 3, color: AppColors.inkMuted),
              const SizedBox(height: 4),
              _bar(widthFactor: 0.9),
              _bar(widthFactor: 0.75),
              const SizedBox(height: 12),
              _bar(widthFactor: 0.3, height: 3, color: AppColors.inkMuted),
              const SizedBox(height: 4),
              _bar(widthFactor: 0.85),
              _bar(widthFactor: 0.5),
            ],
          ),
        ),
      ],
    );
  }
}
