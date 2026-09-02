import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

/// Third agency nav destination — account summary and sign out.
///
/// Sign out used to live as an icon in the shell's top app bar (see
/// `ResponsiveShell`); it now lives here instead, so the agency role hides
/// that icon (`hideLogout: true` in app_router.dart) and this screen is the
/// one place to find it. Mirrors `SeekerAccountScreen`'s structure, scoped
/// down to the fields `AuthUser` actually carries — there's no agency
/// profile endpoint yet (see agency_provider.dart), so this stays a plain
/// account summary rather than an editable profile.
class AgencyAccountScreen extends ConsumerWidget {
  const AgencyAccountScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You\'ll need to log back in to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final user = ref.watch(authProvider).user;
    final identifier = user?.email ?? user?.phone ?? 'Agency account';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.apartment_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identifier,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recruitment agency',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Manage account',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: outline,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text(
                'Sign out',
                style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
