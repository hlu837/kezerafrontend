import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/widgets/theme_toggle_row.dart';
import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../../auth/presentation/auth_provider.dart';
import '../../service_requests/presentation/service_requests_screen.dart';
import '../domain/employer.dart';
import 'employer_advertise_screen.dart';
import 'employer_profile_provider.dart';

/// Employer nav destination — company profile and sign out.
///
/// Sign out used to live as an icon in the shell's top app bar (see
/// `ResponsiveShell`); it now lives here instead, so the employer role
/// hides that icon (`hideLogout: true` in app_router.dart) and this
/// screen is the one place to find it. Mirrors `SeekerAccountScreen`'s
/// structure: a profile card (logo, company name, edit action) backed by
/// `myEmployerProfileProvider` (GET/POST `/employers/me` &
/// `/employers/profile`), plus a "Manage account" section.
class EmployerAccountScreen extends ConsumerWidget {
  const EmployerAccountScreen({super.key});

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
    Employer profile,
  ) async {
    final companyNameController = TextEditingController(text: profile.companyName);
    final phoneController = TextEditingController(text: profile.backofficePhone ?? '');
    final promoController = TextEditingController(text: profile.promoDetails ?? '');
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
                    controller: companyNameController,
                    decoration: const InputDecoration(labelText: 'Company name'),
                    validator: (value) => (value == null || value.trim().length < 2)
                        ? 'Enter at least 2 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Backoffice phone',
                      helperText: 'Used by Kezera for account-related contact.',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final pattern = RegExp(r'^\+?[0-9\s-]{7,20}$');
                      return pattern.hasMatch(value.trim())
                          ? null
                          : 'Enter a valid phone number';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: promoController,
                    decoration: const InputDecoration(
                      labelText: 'About the company',
                      helperText: 'Shown to candidates on your job postings.',
                    ),
                    maxLines: 4,
                    maxLength: 5000,
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
                        await ref.read(myEmployerProfileProvider.notifier).updateProfile(
                              companyName: companyNameController.text.trim(),
                              backofficePhone: phoneController.text.trim(),
                              promoDetails: promoController.text.trim(),
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

  String _initials(String companyName) {
    final parts = companyName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final profileAsync = ref.watch(myEmployerProfileProvider);

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
          profileAsync.when(
            data: (profile) => _ProfileCard(
              profile: profile,
              initials: _initials(profile.companyName),
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
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: profileAsync.valueOrNull == null
                      ? null
                      : () => _showEditProfileDialog(context, ref, profileAsync.value!),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('Advertise', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Promote your company, a service, or a product'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const EmployerAdvertiseScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.handyman_outlined),
                  title: const Text('Service requests', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Bookings you\'ve sent from the Experts/Agencies map'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const ServiceRequestsScreen()),
                  ),
                ),
                const Divider(height: 1),
                const ThemeToggleRow(),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: colorScheme.error),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.initials,
    required this.onEditProfile,
  });

  final Employer profile;
  final String initials;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoPicker(logoUrl: profile.logoUrl, initials: initials),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.companyName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Employer · ${profile.subscriptionTier.label} plan',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (profile.backofficePhone != null && profile.backofficePhone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.backofficePhone!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit profile',
            onPressed: onEditProfile,
          ),
        ],
      ),
    );
  }
}

/// Tapping the logo (or its camera badge) picks an image and uploads it
/// via `POST /employers/logo` (`myEmployerProfileProvider.uploadLogo`).
/// Mirrors `SeekerAccountScreen`'s `_AvatarPicker`.
class _LogoPicker extends ConsumerStatefulWidget {
  const _LogoPicker({required this.logoUrl, required this.initials});

  final String? logoUrl;
  final String initials;

  @override
  ConsumerState<_LogoPicker> createState() => _LogoPickerState();
}

class _LogoPickerState extends ConsumerState<_LogoPicker> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true, // needed for bytes on web
      type: FileType.image,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(myEmployerProfileProvider.notifier).uploadLogo(
            WalkInAttachment(bytes: file.bytes!, filename: file.name),
          );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasLogo = widget.logoUrl != null && widget.logoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _isUploading ? null : _pickAndUpload,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: hasLogo ? NetworkImage(widget.logoUrl!) : null,
            child: _isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : (hasLogo
                    ? null
                    : Text(
                        widget.initials,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: Icon(
                Icons.camera_alt,
                size: 12,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
