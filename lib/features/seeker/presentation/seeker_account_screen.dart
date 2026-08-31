import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/seeker.dart';
import 'seeker_profile_provider.dart';

/// Fourth seeker nav destination — profile summary, job-seeking settings,
/// and sign out. Sign out used to live as an icon in the shell's top app
/// bar (see `ResponsiveShell`); it now lives here instead, so the seeker
/// role hides that icon (`hideLogout: true` in app_router.dart) and this
/// screen is the one place to find it.
///
/// Laid out to match the reference "Profile" design: a profile card up
/// top, a "Job seeking" section with the availability toggle and links
/// into the CV builder / preferences / applications, then a "Manage
/// account" section. Sections from the reference mock with no backing
/// feature in this app (community/posting activity, demographics) are
/// left out rather than shown as dead ends.
class SeekerAccountScreen extends ConsumerWidget {
  const SeekerAccountScreen({super.key});

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

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    Seeker profile,
  ) async {
    final fullNameController = TextEditingController(text: profile.fullName);
    final cityController = TextEditingController(text: profile.city ?? '');
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Edit profile'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (value) => (value == null || value.trim().length < 2)
                        ? 'Enter at least 2 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setState(() {
                        isSaving = true;
                        errorMessage = null;
                      });
                      try {
                        await ref.read(myProfileProvider.notifier).updateProfile(
                              fullName: fullNameController.text.trim(),
                              city: cityController.text.trim(),
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } on ApiException catch (e) {
                        setState(() {
                          isSaving = false;
                          errorMessage = e.message;
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final profileAsync = ref.watch(myProfileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          profileAsync.when(
            data: (profile) => _ProfileBody(
              profile: profile,
              initials: _initials(profile.fullName),
              onEditProfile: () => _showEditProfileDialog(context, ref, profile),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                error is ApiException ? error.message : 'Could not load your profile.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Manage account'),
          const SizedBox(height: 8),
          _AccountCard(
            children: [
              _AccountRow(
                icon: Icons.settings_outlined,
                label: 'Account settings',
                onTap: profileAsync.valueOrNull == null
                    ? null
                    : () => _showEditProfileDialog(context, ref, profileAsync.value!),
              ),
              const Divider(height: 1),
              _AccountRow(
                icon: Icons.logout,
                label: 'Sign out',
                iconColor: colorScheme.error,
                labelColor: colorScheme.error,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.profile,
    required this.initials,
    required this.onEditProfile,
  });

  final Seeker profile;
  final String initials;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final location = profile.city == null || profile.city!.isEmpty
        ? 'Ethiopia'
        : '${profile.city}, Ethiopia';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile card
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
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit profile',
                onPressed: onEditProfile,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const _SectionLabel('Job seeking'),
        const SizedBox(height: 8),
        _AvailabilityPill(profile: profile),
        const SizedBox(height: 16),
        _AccountCard(
          children: [
            _AccountRow(
              icon: Icons.description_outlined,
              label: 'CV and experience',
              onTap: () => context.push('/seeker/onboarding/cv-choice'),
            ),
            const Divider(height: 1),
            _AccountRow(
              icon: Icons.tune_outlined,
              label: 'Job preferences',
              onTap: () => context.push('/seeker/onboarding/preferences'),
            ),
            const Divider(height: 1),
            _AccountRow(
              icon: Icons.assignment_turned_in_outlined,
              label: 'Job activity',
              onTap: () => context.go('/seeker/applications'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AvailabilityPill extends ConsumerWidget {
  const _AvailabilityPill({required this.profile});

  final Seeker profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isVisible = profile.availabilityStatus;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => ref.read(myProfileProvider.notifier).toggleAvailability(!isVisible),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: isVisible ? colorScheme.primary : colorScheme.outline,
              ),
              const SizedBox(width: 10),
              Text(
                isVisible ? 'Hiring employers can find you' : 'Hidden from employer search',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down, size: 20, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
