import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode_controller.dart';

/// "Dark mode" row for a "Manage account" list — same shape as the plain
/// icon + label rows around it, but with a trailing [Switch] instead of a
/// chevron. Used on the seeker, agency, and employer account screens so
/// the toggle behaves identically (and stays in sync) everywhere.
class ThemeToggleRow extends ConsumerWidget {
  const ThemeToggleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    return ListTile(
      leading: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
      title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w500)),
      trailing: Switch(
        value: isDark,
        onChanged: (value) => ref.read(isDarkModeProvider.notifier).setDark(value),
      ),
      onTap: () => ref.read(isDarkModeProvider.notifier).toggle(),
    );
  }
}
