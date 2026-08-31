import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../domain/seeker.dart';
import 'cv_review_screen.dart';
import 'seeker_profile_provider.dart';

/// GET /seekers/me, PATCH /seekers/me, PATCH /seekers/me/availability, and
/// POST /seekers/upload, all live on this one screen — replaces the old
/// static "Welcome!" placeholder (which was copied verbatim from
/// `web-backoffice/src/app/dashboard/seeker/page.tsx`, itself never wired
/// to the backend either).
class SeekerDashboardScreen extends ConsumerWidget {
  const SeekerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(myProfileProvider.notifier).load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job Seeker Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            profileAsync.when(
              data: (profile) => _ProfileContent(profile: profile),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorCard(
                message: error is ApiException
                    ? error.message
                    : 'Could not load your profile.',
                onRetry: () => ref.read(myProfileProvider.notifier).load(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});

  final Seeker profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = Theme.of(context).colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.city ?? 'City not specified',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: outline),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditDialog(context, ref, profile),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  (profile.bio == null || profile.bio!.isEmpty)
                      ? 'No bio yet — tap Edit to add one.'
                      : profile.bio!,
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: (profile.bio == null || profile.bio!.isEmpty)
                                ? outline
                                : null,
                          ),
                ),
                if (profile.skills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in profile.skills)
                        Chip(
                          label: Text(skill),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available for work',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            profile.availabilityStatus
                                ? 'Employers and agencies can find you in candidate searches.'
                                : 'You\'re hidden from candidate searches.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: outline),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: profile.availabilityStatus,
                      onChanged: (value) async {
                        try {
                          await ref
                              .read(myProfileProvider.notifier)
                              .toggleAvailability(value);
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _BoostCard(profile: profile, outline: outline),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documents',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _UploadRow(
                  label: 'CV / Resume',
                  fileUrl: profile.cvUrl,
                  fieldName: 'cv',
                ),
                const SizedBox(height: 12),
                _UploadRow(
                  label: 'Photo',
                  fileUrl: profile.photoUrl,
                  fieldName: 'photo',
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.hasBuilderData
                            ? 'Built with the CV builder'
                            : 'Or build one step by step',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/seeker/onboarding/cv-builder'),
                      icon: const Icon(Icons.edit_note_outlined, size: 18),
                      label: Text(profile.hasBuilderData ? 'Edit CV' : 'Build CV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Seeker profile,
  ) async {
    final fullNameController = TextEditingController(text: profile.fullName);
    final bioController = TextEditingController(text: profile.bio ?? '');
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
                    controller: bioController,
                    decoration: const InputDecoration(labelText: 'Bio'),
                    maxLines: 4,
                    maxLength: 5000,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
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
                              bio: bioController.text.trim(),
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
}

class _UploadRow extends ConsumerStatefulWidget {
  const _UploadRow({
    required this.label,
    required this.fileUrl,
    required this.fieldName,
  });

  final String label;
  final String? fileUrl;
  final String fieldName; // 'cv' or 'photo'

  @override
  ConsumerState<_UploadRow> createState() => _UploadRowState();
}

class _UploadRowState extends ConsumerState<_UploadRow> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true, // needed for bytes on web
      type: widget.fieldName == 'photo' ? FileType.image : FileType.any,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    final attachment = WalkInAttachment(bytes: file.bytes!, filename: file.name);
    // CV-02: snapshot the profile as it stood right before the upload, so
    // that once the upload response comes back (already auto-merged by the
    // backend) we can diff old vs new and tell the seeker what actually
    // came from their CV. Only meaningful for the 'cv' field — a photo
    // upload never touches skills/city/bio.
    final beforeProfile = ref.read(myProfileProvider).value;
    setState(() => _isUploading = true);
    try {
      final afterProfile = await ref.read(myProfileProvider.notifier).uploadFiles(
            cv: widget.fieldName == 'cv' ? attachment : null,
            photo: widget.fieldName == 'photo' ? attachment : null,
          );

      if (widget.fieldName == 'cv' && beforeProfile != null && mounted) {
        await Navigator.of(context, rootNavigator: true).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CvReviewScreen(
              before: beforeProfile,
              after: afterProfile,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.fileUrl != null && widget.fileUrl!.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (hasFile)
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(widget.fileUrl!),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('View'),
          ),
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _pickAndUpload,
          icon: _isUploading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_outlined, size: 18),
          label: Text(hasFile ? 'Replace' : 'Upload'),
        ),
      ],
    );
  }
}

/// SEEK-xx "Boost my profile" — pay a flat ETB 10 fee via Chapa to be
/// shown ahead of non-boosted seekers in employer/agency candidate
/// search (seeker.service.js#searchSeekers) for 6 months. Chapa's
/// checkout is opened externally (same `url_launcher` pattern this file
/// already uses for CVs, see `_UploadRow`'s "View CV" and the class-level
/// import above) rather than shown as a raw URL — payment.routes.js's
/// /verify-callback is what actually sets `boostedUntil` once Chapa
/// confirms the transaction, so this card's "Boosted until ..." state
/// only updates after the person returns here and the profile reloads
/// (see the RefreshIndicator on the outer screen, or reopening the tab).
class _BoostCard extends ConsumerStatefulWidget {
  const _BoostCard({required this.profile, required this.outline});

  final Seeker profile;
  final Color outline;

  @override
  ConsumerState<_BoostCard> createState() => _BoostCardState();
}

class _BoostCardState extends ConsumerState<_BoostCard> {
  bool _isLaunching = false;

  Future<void> _boost() async {
    setState(() => _isLaunching = true);
    try {
      final checkoutUrl =
          await ref.read(myProfileProvider.notifier).initiateBoost();
      await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boostedUntil = widget.profile.boostedUntil;
    final isBoosted = widget.profile.isBoosted;

    return Card(
      color: isBoosted ? AppColors.greenSurface : null,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isBoosted ? Icons.rocket_launch : Icons.rocket_launch_outlined,
              color: AppColors.green,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBoosted ? 'Profile boosted' : 'Boost your profile',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isBoosted && boostedUntil != null
                        ? 'You\'re shown ahead of other candidates until ${_formatDate(boostedUntil)}.'
                        : 'Pay ETB 10 to be shown ahead of other candidates in employer and agency searches for 6 months.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: widget.outline),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isLaunching ? null : _boost,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      side: const BorderSide(color: AppColors.green),
                    ),
                    child: _isLaunching
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isBoosted ? 'Boost again — ETB 10' : 'Boost now — ETB 10'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// No `intl` dependency in this project — hand-rolled to match the
/// convention already used in `interview_schedule_modal.dart`.
String _formatDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
