import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// CV-03: the CV builder wizard's fixed step list, in order. Kept here
/// (rather than duplicated across cv_builder_screen.dart and each step
/// file) so the progress header and the screen's step-switch logic can't
/// drift out of sync.
enum CvBuilderStep {
  personal('Personal', Icons.person_outline),
  experience('Experience', Icons.work_outline),
  education('Education', Icons.school_outlined),
  languages('Languages', Icons.language_outlined),
  template('Template', Icons.palette_outlined),
  review('Review', Icons.check_circle_outline);

  const CvBuilderStep(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Compact numbered progress header shown at the top of every step —
/// tap a completed step's dot to jump back to it.
class CvBuilderProgressHeader extends StatelessWidget {
  const CvBuilderProgressHeader({
    super.key,
    required this.current,
    required this.onStepTapped,
  });

  final CvBuilderStep current;
  final ValueChanged<CvBuilderStep> onStepTapped;

  @override
  Widget build(BuildContext context) {
    const steps = CvBuilderStep.values;
    final currentIndex = current.index;

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final step = steps[index];
          final isDone = index < currentIndex;
          final isCurrent = index == currentIndex;
          final isReachable = index <= currentIndex;

          final Color bg;
          final Color fg;
          if (isCurrent) {
            bg = AppColors.green;
            fg = Colors.white;
          } else if (isDone) {
            bg = AppColors.greenSurface;
            fg = AppColors.greenDark;
          } else {
            bg = AppColors.background;
            fg = AppColors.inkFaint;
          }

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isReachable ? () => onStepTapped(step) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: isCurrent
                    ? null
                    : Border.all(
                        color: isDone ? AppColors.greenSurface : AppColors.border,
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDone ? Icons.check : step.icon,
                    size: 16,
                    color: fg,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Consistent section card wrapper used by every step's body content.
class CvBuilderSectionCard extends StatelessWidget {
  const CvBuilderSectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          description,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.inkMuted, height: 1.4),
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

/// Bottom Back/Next (or Back/Generate) navigation bar, shared by every
/// step so button placement/styling never drifts between steps.
class CvBuilderNavBar extends StatelessWidget {
  const CvBuilderNavBar({
    super.key,
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'Continue',
    this.isNextLoading = false,
    this.backLabel = 'Back',
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool isNextLoading;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          Expanded(
            child: OutlinedButton(
              onPressed: isNextLoading ? null : onBack,
              child: Text(backLabel),
            ),
          ),
        if (onBack != null) const SizedBox(width: 12),
        Expanded(
          flex: onBack != null ? 2 : 1,
          child: ElevatedButton(
            onPressed: isNextLoading ? null : onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: isNextLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    nextLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A single editable-list row (used by the Experience/Education/Languages
/// steps) — a compact card with a title/subtitle, edit, and delete action.
class CvBuilderListTile extends StatelessWidget {
  const CvBuilderListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailingBadge,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String? trailingBadge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    if (trailingBadge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.greenSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          trailingBadge!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greenDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.inkMuted, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
            tooltip: 'Remove',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Empty-state placeholder shown by the Experience/Education/Languages
/// steps before any entries have been added.
class CvBuilderEmptyState extends StatelessWidget {
  const CvBuilderEmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.inkFaint, size: 28),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkFaint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
