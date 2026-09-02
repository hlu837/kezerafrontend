import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/widgets/skill_tag_input.dart';
import '../domain/agency_models.dart';
import 'agency_provider.dart';

/// Mirrors `web-backoffice/src/app/agency/walk-in/page.tsx` — same fields,
/// same validation rules (name ≥2 chars, phone pattern, optional email
/// format), plus optional CV/photo attachments.
class WalkInRegistrationScreen extends ConsumerStatefulWidget {
  const WalkInRegistrationScreen({super.key});

  @override
  ConsumerState<WalkInRegistrationScreen> createState() =>
      _WalkInRegistrationScreenState();
}

class _WalkInRegistrationScreenState
    extends ConsumerState<WalkInRegistrationScreen> {
  static final _phonePattern = RegExp(r'^\+?[0-9\s-]{7,20}$');
  static final _emailPattern = RegExp(r'^\S+@\S+\.\S+$');

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  List<String> _skills = [];
  PlatformFile? _cvFile;
  PlatformFile? _photoFile;
  bool _isSubmitting = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _fullNameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _cityController.clear();
    _bioController.clear();
    setState(() {
      _skills = [];
      _cvFile = null;
      _photoFile = null;
    });
  }

  Future<void> _pickFile({
    required List<String>? allowedExtensions,
    required ValueChanged<PlatformFile?> onPicked,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions == null ? FileType.image : FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true, // needed for bytes on web
    );
    if (result != null && result.files.isNotEmpty) {
      onPicked(result.files.single);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _successMessage = null;
    });

    final formOk = _formKey.currentState!.validate();
    if (!formOk) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(agencyRepositoryProvider).registerWalkIn(
            WalkInPayload(
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim().isEmpty
                  ? null
                  : _emailController.text.trim(),
              city: _cityController.text.trim().isEmpty
                  ? null
                  : _cityController.text.trim(),
              bio: _bioController.text.trim().isEmpty
                  ? null
                  : _bioController.text.trim(),
              skills: _skills,
            ),
            cv: _toAttachment(_cvFile),
            photo: _toAttachment(_photoFile),
          );
      if (!mounted) return;
      setState(() {
        _successMessage = '${result.fullName} was registered successfully.';
      });
      _resetForm();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to register candidate. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  WalkInAttachment? _toAttachment(PlatformFile? file) {
    if (file == null || file.bytes == null) return null;
    return WalkInAttachment(bytes: file.bytes!, filename: file.name);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Walk-in registration',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Quickly register a candidate who's visited the "
                          'office in person.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/agency/placements'),
                    child: const Text('View placements'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                _Banner(
                  message: _error!,
                  background: Theme.of(context).colorScheme.errorContainer,
                  foreground: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(height: 16),
              ],
              if (_successMessage != null) ...[
                _Banner(
                  message: _successMessage!,
                  background: Colors.green.shade50,
                  foreground: Colors.green.shade700,
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'Abebe Kebede',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().length < 2)
                                ? 'Full name is required.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          hintText: '+251911234567',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || !_phonePattern.hasMatch(value.trim()))
                                ? 'Enter a valid phone number.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          hintText: 'candidate@example.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          return _emailPattern.hasMatch(value.trim())
                              ? null
                              : 'Enter a valid email address.';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _cityController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'City (optional)',
                          hintText: 'Addis Ababa',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SkillTagInput(
                        label: 'Skills (optional)',
                        skills: _skills,
                        onChanged: (skills) => setState(() => _skills = skills),
                        hintText: 'e.g. Housekeeping — press Enter',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _bioController,
                        enabled: !_isSubmitting,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText:
                              'Any relevant background or notes from the '
                              'intake conversation',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _FilePickerField(
                              label: 'CV / Bio-data (optional)',
                              fileName: _cvFile?.name,
                              onPick: _isSubmitting
                                  ? null
                                  : () => _pickFile(
                                        allowedExtensions: const [
                                          'pdf',
                                          'doc',
                                          'docx',
                                          'jpg',
                                          'jpeg',
                                          'png',
                                        ],
                                        onPicked: (f) =>
                                            setState(() => _cvFile = f),
                                      ),
                              onClear: _cvFile == null
                                  ? null
                                  : () => setState(() => _cvFile = null),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FilePickerField(
                              label: 'Photo (optional)',
                              fileName: _photoFile?.name,
                              onPick: _isSubmitting
                                  ? null
                                  : () => _pickFile(
                                        allowedExtensions: null,
                                        onPicked: (f) =>
                                            setState(() => _photoFile = f),
                                      ),
                              onClear: _photoFile == null
                                  ? null
                                  : () => setState(() => _photoFile = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Register candidate'),
                      ),
                    ],
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.background,
    required this.foreground,
  });

  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: foreground)),
    );
  }
}

class _FilePickerField extends StatelessWidget {
  const _FilePickerField({
    required this.label,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String? fileName;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.attach_file, size: 18),
          label: Text(
            fileName ?? 'Choose file',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (fileName != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onClear,
              child: const Text('Remove'),
            ),
          ),
      ],
    );
  }
}
