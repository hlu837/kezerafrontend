import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Mirrors `web-backoffice/src/components/AvailabilityBadge.tsx`.
class AvailabilityBadgeWidget extends StatelessWidget {
  const AvailabilityBadgeWidget({super.key, required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = available
        ? ('Available', AppColors.greenSurface, AppColors.greenDark)
        : ('Unavailable', AppColors.background, AppColors.inkMuted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
