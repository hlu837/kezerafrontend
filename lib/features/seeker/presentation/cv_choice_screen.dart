import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import '../../auth/domain/user_model.dart';
import 'cv_review_screen.dart';
import 'seeker_profile_provider.dart';

/// SEEK-01b: CV Setup screen — shown right after
/// [CategoryPreferencesScreen]'s "Save & Continue", before the seeker ever
/// lands on their dashboard.
///
/// Presents the two ways a seeker can get a CV onto their profile:
///   1. Upload an existing CV file (`POST /seekers/upload`, same call the
///      dashboard's "CV / Resume" upload row makes — see
///      `seeker_dashboard_screen.dart#_UploadRow`). On success we push the
///      same [CvReviewScreen] the dashboard uses, so the autofill-review UX
///      is identical no matter where the upload happened from.
///   2. Build a CV from scratch. The actual builder flow isn't implemented
///      yet, so this just routes to a placeholder screen
///      (`cv_builder_screen.dart`) for now.
///
/// Standalone route (`/seeker/onboarding/cv-choice`), outside the
/// [ShellRoute] — same reasoning as [CategoryPreferencesScreen]: no
/// sidebar/bottom-nav chrome while onboarding is still in progress.
class CvChoiceScreen extends ConsumerStatefulWidget {
  const CvChoiceScreen({super.key});

  @override
  ConsumerState<CvChoiceScreen> createState() => _CvChoiceScreenState();
}

class _CvChoiceScreenState extends ConsumerState<CvChoiceScreen> {
  bool _isUploading = false;
  String? _errorMessage;

  void _goToDashboard() {
    if (mounted) context.go(UserRole.seeker.dashboardPath);
  }

  Future<void> _pickAndUploadCv() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true, // needed for bytes on web
      type: FileType.any,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    final attachment = WalkInAttachment(bytes: file.bytes!, filename: file.name);
    // Snapshot the profile as it stood right before the upload — same
    // before/after diff CV-02's review screen relies on, see
    // seeker_dashboard_screen.dart#_UploadRow for the identical pattern.
    final beforeProfile = ref.read(myProfileProvider).value;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final afterProfile =
          await ref.read(myProfileProvider.notifier).uploadFiles(cv: attachment);

      if (beforeProfile != null && mounted) {
        await Navigator.of(context, rootNavigator: true).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CvReviewScreen(before: beforeProfile, after: afterProfile),
          ),
        );
      }
      _goToDashboard();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not upload your CV. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _goToBuilder() {
    context.go('/seeker/onboarding/cv-builder');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 28),
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 20),
                  ],
                  _CvOptionCard(
                    icon: Icons.upload_file_outlined,
                    title: 'Upload your CV',
                    description:
                        'Already have a CV? Upload it and we\'ll pull out your '
                        'skills, city, and bio automatically.',
                    buttonLabel: 'Upload CV',
                    isLoading: _isUploading,
                    onTap: _isUploading ? null : _pickAndUploadCv,
                  ),
                  const SizedBox(height: 16),
                  _CvOptionCard(
                    icon: Icons.edit_note_outlined,
                    title: 'Build your CV',
                    description:
                        'No CV yet? Build one step by step right inside the app.',
                    buttonLabel: 'Build CV',
                    isLoading: false,
                    onTap: _isUploading ? null : _goToBuilder,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _isUploading ? null : _goToDashboard,
                      style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
                      child: const Text('Skip for now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Let\'s set up your CV',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Employers and agencies see this before anything else. Upload '
          'one you already have, or build one now.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.inkMuted, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CvOptionCard extends StatelessWidget {
  const _CvOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.greenSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.greenDark, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.inkMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      side: const BorderSide(color: AppColors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
