import 'package:flutter/material.dart';

/// Shared "coming soon" body for admin sidebar destinations that don't have
/// a backend endpoint yet (see backend/src/controllers/admin.controller.js
/// — only verifications is implemented today). Keeping this as one shared
/// widget means wiring up the real screen later is a matter of swapping the
/// route's builder in app_router.dart, without touching admin_shell.dart or
/// the redirect/RBAC guards.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 40, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Coming soon',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
