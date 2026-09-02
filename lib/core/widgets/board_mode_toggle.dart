import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Which side of the guest landing page toggle is active.
enum BoardMode {
  /// Default — browsing open jobs. Aimed at job seekers.
  jobs,

  /// Browsing available talent instead. Aimed at employers/agencies
  /// previewing candidates before signing up (see
  /// `PublicCandidatesBoardScreen`).
  experts,
}

/// The "Jobs / Experts" segmented toggle shown next to the "Find a job"
/// / "Find talent" heading on the public landing page. Defaults to
/// [BoardMode.jobs] — a guest lands on the job board; switching to
/// [BoardMode.experts] swaps the whole page over to browsing seekers,
/// for the employer/agency visitors who came here to look for talent
/// instead of a job.
class BoardModeToggle extends StatelessWidget {
  const BoardModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final BoardMode mode;
  final ValueChanged<BoardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, label: 'Jobs', value: BoardMode.jobs),
          _segment(context, label: 'Experts', value: BoardMode.experts),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, {required String label, required BoardMode value}) {
    final selected = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
