import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/widgets/skill_tag_input.dart';
import '../../seeker/domain/job_category.dart';
import '../domain/job.dart';
import 'jobs_provider.dart';

/// Mirrors `web-backoffice/src/app/employer/jobs/new/page.tsx` — same
/// fields, same validation rules (title ≥3 chars, description ≥10 chars,
/// location + job type required, at least one skill).
class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryRangeController = TextEditingController();

  JobType? _jobType;
  // JS-04: optional — kept nullable ("Uncategorized") rather than
  // required, since existing jobs were posted before this field existed
  // and a required dropdown here would be a breaking change to the form.
  String? _category;
  List<String> _skills = [];
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryRangeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final formOk = _formKey.currentState!.validate();
    if (_jobType == null) {
      setState(() => _error = 'Select a job type.');
      return;
    }
    if (_skills.isEmpty) {
      setState(() => _error = 'Add at least one required skill.');
      return;
    }
    if (!formOk) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(myJobsProvider.notifier).createJob(
            CreateJobPayload(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              location: _locationController.text.trim(),
              salaryRange: _salaryRangeController.text.trim().isEmpty
                  ? null
                  : _salaryRangeController.text.trim(),
              jobType: _jobType!,
              category: _category,
              skillsRequired: _skills,
            ),
          );
      if (mounted) context.go('/employer/dashboard');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to post job. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
              Text('Post a job', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                "Fill in the details below — we'll start matching "
                "candidates as soon as it's live.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
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
                        controller: _titleController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Job Title',
                          hintText: 'e.g. Warehouse Supervisor',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().length < 3)
                                ? 'Title must be at least 3 characters.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_isSubmitting,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText:
                              'Describe the role, responsibilities, and requirements',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            (value == null || value.trim().length < 10)
                                ? 'Description must be at least 10 characters.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _locationController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'Addis Ababa, Bole',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Location is required.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<JobType>(
                        initialValue: _jobType,
                        decoration: const InputDecoration(
                          labelText: 'Job Type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final type in JobType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.wireValue),
                            ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _jobType = value),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                          helperText: 'Helps seekers filter for this kind of role.',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Uncategorized')),
                          for (final category in kJobCategories)
                            DropdownMenuItem(
                              value: category.key,
                              child: Text(category.label),
                            ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _category = value),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _salaryRangeController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Salary Range (optional)',
                          hintText: 'e.g. ETB 8,000 – 12,000 / month',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SkillTagInput(
                        label: 'Required Skills',
                        skills: _skills,
                        onChanged: (skills) => setState(() => _skills = skills),
                        hintText: 'e.g. Forklift operation — press Enter',
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
                            : const Text('Post job'),
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
