import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../domain/seeker.dart';
import 'cv_builder_education_step.dart';
import 'cv_builder_experience_step.dart';
import 'cv_builder_languages_step.dart';
import 'cv_builder_personal_step.dart';
import 'cv_builder_review_step.dart';
import 'cv_builder_shared.dart';
import 'cv_builder_template_step.dart';
import 'seeker_profile_provider.dart';

/// CV-03: the step-by-step CV builder flow, reached from
/// [CvChoiceScreen]'s "Build CV" option (`/seeker/onboarding/cv-builder`)
/// or later from the dashboard's "Edit CV" action once a seeker already
/// has builder data.
///
/// Walks the seeker through 6 steps — personal details, experience,
/// education, languages, template choice, and a final review — entirely
/// client-side, then submits everything in one shot at the end:
///   - personal fields (name/city/summary/skills) go through the regular
///     `PATCH /seekers/me` profile update, since those already exist on
///     the seeker's profile and other screens (dashboard edit dialog,
///     CV review screen) read/write the same fields.
///   - experience/education/languages/template go through the CV
///     builder's own `POST /seekers/me/cv-builder/generate`, which both
///     persists that structured data AND renders + uploads the PDF,
///     setting `cvUrl` the same way a plain file upload would.
class CvBuilderScreen extends ConsumerStatefulWidget {
  const CvBuilderScreen({super.key});

  @override
  ConsumerState<CvBuilderScreen> createState() => _CvBuilderScreenState();
}

class _CvBuilderScreenState extends ConsumerState<CvBuilderScreen> {
  CvBuilderStep _step = CvBuilderStep.personal;
  bool _initialized = false;

  late final TextEditingController _fullNameController;
  late final TextEditingController _cityController;
  late final TextEditingController _summaryController;
  List<String> _skills = [];
  List<CvExperience> _experience = [];
  List<CvEducation> _education = [];
  List<CvLanguage> _languages = [];
  CvTemplate _template = CvTemplate.classic;

  bool _isSaving = false;
  bool _isGenerating = false;
  String? _errorMessage;
  String? _generatedCvUrl;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _cityController = TextEditingController();
    _summaryController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  /// Seeds every field from the seeker's current profile the first time
  /// it becomes available. Guarded by [_initialized] so a rebuild from
  /// e.g. the provider updating mid-wizard (after "Save & exit" or
  /// "Generate") never clobbers what the seeker has typed.
  void _seedFromProfile(Seeker profile) {
    if (_initialized) return;
    _initialized = true;
    _fullNameController.text = profile.fullName;
    _cityController.text = profile.city ?? '';
    _summaryController.text = profile.bio ?? '';
    _skills = List.of(profile.skills);
    _experience = List.of(profile.experience);
    _education = List.of(profile.education);
    _languages = List.of(profile.languages);
    _template = profile.cvTemplate;
  }

  void _goToStep(CvBuilderStep step) => setState(() => _step = step);

  void _goBack() {
    const steps = CvBuilderStep.values;
    final index = steps.indexOf(_step);
    if (index > 0) _goToStep(steps[index - 1]);
  }

  void _goNext() {
    const steps = CvBuilderStep.values;
    final index = steps.indexOf(_step);
    if (index < steps.length - 1) _goToStep(steps[index + 1]);
  }

  /// Prefers popping back to wherever the seeker came from (e.g. the
  /// dashboard's "Edit CV" button, which reaches this screen via
  /// `context.push`) and only falls back to an explicit redirect to the
  /// dashboard when there's nothing to pop to — i.e. when this screen was
  /// reached via `context.go` from the SEEK-01b onboarding flow, which
  /// replaces rather than pushes.
  void _exitToDashboard() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(UserRole.seeker.dashboardPath);
    }
  }

  /// Persists everything gathered so far WITHOUT generating a PDF — used
  /// by the "Save & exit" app bar action so a seeker who backs out
  /// midway keeps their progress next time they open the builder.
  Future<void> _saveAndExit() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(myProfileProvider.notifier).updateProfile(
            fullName: _fullNameController.text.trim(),
            bio: _summaryController.text.trim(),
            skills: _skills,
            city: _cityController.text.trim(),
          );
      await ref.read(myProfileProvider.notifier).saveCvBuilderData(
            experience: _experience,
            education: _education,
            languages: _languages,
            template: _template,
          );
      _exitToDashboard();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    try {
      // Personal fields first (separate endpoint — see class doc), then
      // the CV builder's own save-and-render call. If the first succeeds
      // but the second fails, the seeker's regular profile is still
      // correctly saved; retrying "Generate CV" only re-runs the second.
      await ref.read(myProfileProvider.notifier).updateProfile(
            fullName: _fullNameController.text.trim(),
            bio: _summaryController.text.trim(),
            skills: _skills,
            city: _cityController.text.trim(),
          );
      final updated = await ref.read(myProfileProvider.notifier).generateCv(
            template: _template,
            experience: _experience,
            education: _education,
            languages: _languages,
          );
      setState(() => _generatedCvUrl = updated.cvUrl);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not generate your CV. Please try again.');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _viewCv() {
    if (_generatedCvUrl == null) return;
    launchUrl(Uri.parse(_generatedCvUrl!), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Build your CV'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _isSaving || _isGenerating
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/seeker/onboarding/cv-choice');
                  }
                },
        ),
        actions: [
          if (_generatedCvUrl == null)
            TextButton(
              onPressed: _isSaving || _isGenerating ? null : _saveAndExit,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & exit'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: profileState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load your profile: $error'),
            ),
          ),
          data: (profile) {
            _seedFromProfile(profile);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    if (_generatedCvUrl == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                        child: CvBuilderProgressHeader(
                          current: _step,
                          onStepTapped: _goToStep,
                        ),
                      ),
                    Expanded(child: _buildStep()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_generatedCvUrl != null) {
      return CvBuilderReviewStep(
        fullName: _fullNameController.text,
        city: _cityController.text,
        summary: _summaryController.text,
        skills: _skills,
        experience: _experience,
        education: _education,
        languages: _languages,
        template: _template,
        onBack: null,
        onGenerate: _generate,
        onEditStep: _goToStep,
        isGenerating: _isGenerating,
        errorMessage: _errorMessage,
        generatedCvUrl: _generatedCvUrl,
        onViewCv: _viewCv,
        onDone: _exitToDashboard,
      );
    }

    return switch (_step) {
      CvBuilderStep.personal => CvBuilderPersonalStep(
          fullNameController: _fullNameController,
          cityController: _cityController,
          summaryController: _summaryController,
          skills: _skills,
          onSkillsChanged: (v) => setState(() => _skills = v),
          onBack: null,
          onNext: _goNext,
        ),
      CvBuilderStep.experience => CvBuilderExperienceStep(
          entries: _experience,
          onChanged: (v) => setState(() => _experience = v),
          onBack: _goBack,
          onNext: _goNext,
        ),
      CvBuilderStep.education => CvBuilderEducationStep(
          entries: _education,
          onChanged: (v) => setState(() => _education = v),
          onBack: _goBack,
          onNext: _goNext,
        ),
      CvBuilderStep.languages => CvBuilderLanguagesStep(
          entries: _languages,
          onChanged: (v) => setState(() => _languages = v),
          onBack: _goBack,
          onNext: _goNext,
        ),
      CvBuilderStep.template => CvBuilderTemplateStep(
          selected: _template,
          onChanged: (v) => setState(() => _template = v),
          onBack: _goBack,
          onNext: _goNext,
        ),
      CvBuilderStep.review => CvBuilderReviewStep(
          fullName: _fullNameController.text,
          city: _cityController.text,
          summary: _summaryController.text,
          skills: _skills,
          experience: _experience,
          education: _education,
          languages: _languages,
          template: _template,
          onBack: _goBack,
          onGenerate: _generate,
          onEditStep: _goToStep,
          isGenerating: _isGenerating,
          errorMessage: _errorMessage,
          generatedCvUrl: _generatedCvUrl,
          onViewCv: _viewCv,
          onDone: _exitToDashboard,
        ),
    };
  }
}
