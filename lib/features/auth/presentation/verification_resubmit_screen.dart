import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../agency/domain/agency_models.dart' show WalkInAttachment;
import 'auth_provider.dart';

/// Reached from the "Resubmit Documents" button on
/// [VerificationStatusScreen] once an employer/agency has been rejected.
/// Lets them attach a corrected business license and re-enter the admin
/// approval queue via `POST /verification/license` +
/// `POST /verification/resubmit`.
class VerificationResubmitScreen extends ConsumerStatefulWidget {
  const VerificationResubmitScreen({super.key});

  @override
  ConsumerState<VerificationResubmitScreen> createState() =>
      _VerificationResubmitScreenState();
}

class _VerificationResubmitScreenState
    extends ConsumerState<VerificationResubmitScreen> {
  WalkInAttachment? _licenseFile;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _licenseFile = WalkInAttachment(bytes: file.bytes!, filename: file.name);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_licenseFile == null) {
      setState(() => _errorMessage = 'Please attach your corrected document first.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(verificationRepositoryProvider);
      await repository.uploadLicense(_licenseFile!);
      final updatedUser = await repository.resubmit();
      await ref.read(authProvider.notifier).updateUser(updatedUser);

      if (!mounted) return;
      context.go('/verification-status');
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejectionReason =
        ref.watch(authProvider.select((s) => s.user?.verificationRejectionReason));
    final hasFile = _licenseFile != null;

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/verification-status'),
        ),
        title: const Text('Resubmit Documents', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attach a corrected business license',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Upload a clear copy of your TIN certificate or business license. '
                'Once submitted, your account goes back into the review queue.',
                style: TextStyle(color: Colors.white.withOpacity(0.65), height: 1.5),
              ),
              if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE57373).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFE57373), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Why it was rejected',
                            style: TextStyle(
                              color: const Color(0xFFE57373).withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rejectionReason,
                        style: const TextStyle(color: Colors.white, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              InkWell(
                onTap: _isSubmitting ? null : _pickFile,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasFile
                          ? AppColors.green
                          : Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasFile ? Icons.task_outlined : Icons.upload_file_rounded,
                        color: hasFile ? AppColors.green : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          hasFile
                              ? _licenseFile!.filename
                              : 'Tap to attach a document (PDF, JPG or PNG)',
                          style: TextStyle(
                            color: hasFile ? Colors.white : Colors.white70,
                            fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFE57373), fontSize: 13),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit for Review',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
