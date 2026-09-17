import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/widgets/theme_toggle_row.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/agency_models.dart';
import 'agency_provider.dart';

/// Fourth agency nav destination — profile view/edit and sign out.
///
/// Sign out used to live as an icon in the shell's top app bar (see
/// `ResponsiveShell`); it now lives here instead, so the agency role
/// hides that icon (`hideLogout: true` in app_router.dart) and this
/// screen is the one place to find it. Mirrors `EmployerAccountScreen`'s
/// structure: a profile card (logo, agency name, city, phone, edit
/// action) backed by `myAgencyProfileProvider` (GET/POST `/agencies/me`,
/// `/agencies/profile` & `/agencies/logo`), plus a "Manage account"
/// section. A bio and/or logo is required before this agency can post
/// its first job (see `requireAgencyPublicProfile.middleware.js` on the
/// backend) — an agency with neither sees a banner nudging it to add
/// one; agencies that already had a job posted before this requirement
/// shipped are grandfathered in and never see the block, though the
/// banner still shows as a general profile-completeness nudge.
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

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    AgencyProfile profile,
  ) async {
    final agencyNameController = TextEditingController(text: profile.agencyName);
    final cityController = TextEditingController(text: profile.operationalCity ?? '');
    final phoneController = TextEditingController(text: profile.backofficePhone ?? '');
    final addressController = TextEditingController(text: profile.address ?? '');
    final bioController = TextEditingController(text: profile.bio ?? '');
    final foundedYearController =
        TextEditingController(text: profile.foundedYear?.toString() ?? '');
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
                    controller: agencyNameController,
                    decoration: const InputDecoration(labelText: 'Agency name'),
                    validator: (value) => (value == null || value.trim().length < 2)
                        ? 'Enter at least 2 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'Operational city',
                      helperText: 'Shown to seekers on your job postings.',
                    ),
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
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Office address',
                      helperText: 'Shown on the "Find agencies near you" map so seekers can find your office.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: foundedYearController,
                    decoration: const InputDecoration(
                      labelText: 'Founded year',
                      helperText: 'Shown as "years in business" on your directory card and public profile.',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final year = int.tryParse(value.trim());
                      final currentYear = DateTime.now().year;
                      if (year == null || year < 1900 || year > currentYear) {
                        return 'Enter a year between 1900 and $currentYear';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bioController,
                    decoration: const InputDecoration(
                      labelText: 'About the agency',
                      helperText: 'Shown to candidates and employers on your job postings. '
                          'A bio or logo is needed before you can post your first job.',
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
                        final foundedYearText = foundedYearController.text.trim();
                        await ref.read(myAgencyProfileProvider.notifier).updateProfile(
                              agencyName: agencyNameController.text.trim(),
                              operationalCity: cityController.text.trim(),
                              backofficePhone: phoneController.text.trim(),
                              address: addressController.text.trim(),
                              bio: bioController.text.trim(),
                              foundedYear: foundedYearText.isEmpty
                                  ? null
                                  : int.tryParse(foundedYearText),
                              clearFoundedYear: foundedYearText.isEmpty,
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

  String _initials(String agencyName) {
    final parts = agencyName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final profileAsync = ref.watch(myAgencyProfileProvider);

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
            data: (profile) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!profile.hasPublicProfile) ...[
                  _IncompleteProfileBanner(
                    onAddProfile: () => _showEditProfileDialog(context, ref, profile),
                  ),
                  const SizedBox(height: 16),
                ],
                _ProfileCard(
                  profile: profile,
                  initials: _initials(profile.agencyName),
                  onEditProfile: () => _showEditProfileDialog(context, ref, profile),
                ),
              ],
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
                  leading: const Icon(Icons.handyman_outlined),
                  title: const Text('Service requests', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Requests routed to your agency, and any you\'ve sent'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/agency/service-requests'),
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

  final AgencyProfile profile;
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
                  profile.agencyName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recruitment agency · ${profile.subscriptionTier.label} plan',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (profile.operationalCity != null && profile.operationalCity!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.operationalCity!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                  ),
                ],
                if (profile.backofficePhone != null && profile.backofficePhone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.backofficePhone!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                  ),
                ],
                if (profile.address != null && profile.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.address!,
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

/// Nudges an agency with neither a bio nor a logo to add one, before it
/// hits the hard block on `POST /jobs/create` (see
/// `requireAgencyPublicProfile.middleware.js`). Shown on every visit to
/// this screen until either field is set — including for grandfathered
/// agencies (ones that already had a job posted before this requirement
/// shipped), since it's a genuinely useful nudge for them too, even
/// though the backend will never actually block their job posting.
class _IncompleteProfileBanner extends StatelessWidget {
  const _IncompleteProfileBanner({required this.onAddProfile});

  final VoidCallback onAddProfile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your public profile',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onTertiaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a bio or a logo so candidates and employers know who you are. '
                  'You\'ll need at least one before you can post your first job.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onAddProfile,
                  child: const Text('Add bio or logo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tapping the logo (or its camera badge) picks an image and uploads it
/// via `POST /agencies/logo` (`myAgencyProfileProvider.uploadLogo`).
/// Mirrors `EmployerAccountScreen`'s `_LogoPicker`.
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
      await ref.read(myAgencyProfileProvider.notifier).uploadLogo(
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
