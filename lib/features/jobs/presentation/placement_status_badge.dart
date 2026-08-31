import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/placement.dart';

/// Mirrors `web-backoffice/src/components/PlacementStatusBadge.tsx`'s
/// tone mapping (blue/amber/green/red), rendered in the same pill style
/// as [JobStatusBadge] so the two badge types read consistently.
class PlacementStatusBadgeWidget extends StatelessWidget {
  const PlacementStatusBadgeWidget({super.key, required this.status});

  final PlacementStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      PlacementStatus.matched => (
          'Matched',
          Colors.blue.shade50,
          Colors.blue.shade700,
        ),
      PlacementStatus.sent => (
          'Sent',
          Colors.amber.shade50,
          Colors.amber.shade800,
        ),
      PlacementStatus.interviewed => (
          'Interviewed',
          Colors.purple.shade50,
          Colors.purple.shade700,
        ),
      PlacementStatus.hired => (
          'Hired',
          AppColors.greenSurface,
          AppColors.greenDark,
        ),
      PlacementStatus.rejected => (
          'Rejected',
          Colors.red.shade50,
          Colors.red.shade700,
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
