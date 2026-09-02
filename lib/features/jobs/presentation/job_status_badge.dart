import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/job.dart';

class JobStatusBadge extends StatelessWidget {
  const JobStatusBadge({super.key, required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      JobStatus.open => (
          'Open',
          AppColors.greenSurface,
          AppColors.greenDark,
        ),
      JobStatus.closed => (
          'Closed',
          Colors.grey.shade100,
          Colors.grey.shade700,
        ),
      JobStatus.draft => (
          'Draft',
          Colors.amber.shade50,
          Colors.amber.shade800,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
