import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/location/device_location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../domain/expert_trade_category.dart';
import '../domain/technician.dart';
import 'technician_profile_provider.dart';

/// SEEK-01c continued / account-screen entry point: the lightweight
/// Trade Technician profile form — name, trade, skills, location, rate.
/// Deliberately short next to the multi-step CV builder: no CV,
/// experience, or education fields (see `Technician.model.js`'s
/// top-of-file note and `updateProfileSchema`'s doc comment on the
/// backend for why).
///
/// Serves two entry points with the same form:
///   - **Onboarding** (reached via `context.go` from
///     [ExpertTypeChoiceScreen], no back stack) — registers a brand-new
///     profile, then continues to the dashboard.
///   - **Editing** (reached via `context.push` from the account
///     screen's "Job seeking" section) — loads the existing profile
///     into the form, saves changes, then pops back.
/// [Navigator.canPop] distinguishes the two once the save succeeds,
/// same convention already used elsewhere in this onboarding flow.
class TechnicianRegistrationScreen extends ConsumerStatefulWidget {
  const TechnicianRegistrationScreen({super.key});

  @override
  ConsumerState<TechnicianRegistrationScreen> createState() =>
      _TechnicianRegistrationScreenState();
}

class _TechnicianRegistrationScreenState
    extends ConsumerState<TechnicianRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _skillInputController = TextEditingController();
  final _rateAmountController = TextEditingController();

  String? _tradeCategory;
  final List<String> _skills = [];
  TechnicianRateUnit? _rateUnit;

  double? _capturedLatitude;
  double? _capturedLongitude;
  bool _isCapturingLocation = false;
  String? _locationError;

  bool _isSaving = false;
  String? _formError;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // Best-effort load of an existing profile — a brand-new seeker
    // reaching this from onboarding almost certainly has none yet (see
    // MyTechnicianProfileNotifier's doc comment: that's the expected
    // "data: null" case, not an error), in which case the form just
    // stays blank.
    Future.microtask(() => ref.read(myTechnicianProfileProvider.notifier).load());
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _skillInputController.dispose();
    _rateAmountController.dispose();
    super.dispose();
  }

  void _prefillFrom(Technician profile) {
    if (_prefilled) return;
    _prefilled = true;
    _fullNameController.text = profile.fullName;
    _tradeCategory = profile.tradeCategory;
    _skills.addAll(profile.skills);
    _rateUnit = profile.rateUnit;
    if (profile.rateAmount != null) {
      final amount = profile.rateAmount!;
      _rateAmountController.text =
          amount.truncateToDouble() == amount ? amount.toStringAsFixed(0) : amount.toString();
    }
    _capturedLatitude = profile.latitude;
    _capturedLongitude = profile.longitude;
  }

  void _addSkill() {
    final value = _skillInputController.text.trim();
    if (value.isEmpty || _skills.contains(value)) {
      _skillInputController.clear();
      return;
    }
    setState(() {
      _skills.add(value);
      _skillInputController.clear();
    });
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isCapturingLocation = true;
      _locationError = null;
    });
    try {
      final position = await const DeviceLocationService().getCurrentLatLng();
      setState(() {
        _capturedLatitude = position.latitude;
        _capturedLongitude = position.longitude;
      });
    } on DeviceLocationException catch (e) {
      setState(() => _locationError = switch (e.reason) {
            DeviceLocationFailure.servicesDisabled =>
              'Location services are turned off on this device.',
            DeviceLocationFailure.permissionDenied => 'Location access was declined.',
            DeviceLocationFailure.permissionDeniedForever =>
              "Location access is blocked. Enable it from your device's Settings.",
            DeviceLocationFailure.positionUnavailable =>
              "Couldn't get your current location. Try again.",
          });
    } catch (_) {
      setState(() => _locationError = "Couldn't get your current location.");
    } finally {
      if (mounted) setState(() => _isCapturingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tradeCategory == null) {
      setState(() => _formError = 'Choose the trade that best fits you.');
      return;
    }

    setState(() {
      _isSaving = true;
      _formError = null;
    });

    final rateAmountText = _rateAmountController.text.trim();
    final rateAmount = rateAmountText.isEmpty ? null : double.tryParse(rateAmountText);
    if (rateAmountText.isNotEmpty && (rateAmount == null || _rateUnit == null)) {
      setState(() {
        _isSaving = false;
        _formError = 'Enter a valid rate and choose how it\'s billed.';
      });
      return;
    }

    try {
      await ref.read(myTechnicianProfileProvider.notifier).save(
            fullName: _fullNameController.text.trim(),
            tradeCategory: _tradeCategory!,
            skills: _skills,
            rateAmount: rateAmount,
            rateUnit: rateAmount != null ? _rateUnit : null,
            clearRate: rateAmount == null,
          );

      // Best-effort — a failed location save shouldn't block finishing
      // registration, same reasoning as the Seeker onboarding flow
      // (category_preferences_screen.dart).
      if (_capturedLatitude != null && _capturedLongitude != null) {
        try {
          await ref.read(myTechnicianProfileProvider.notifier).updateLocation(
                latitude: _capturedLatitude!,
                longitude: _capturedLongitude!,
              );
        } catch (_) {
          // Ignored — see comment above.
        }
      }

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(UserRole.seeker.dashboardPath);
      }
    } on ApiException catch (e) {
      setState(() {
        _isSaving = false;
        _formError = e.message;
      });
    } catch (_) {
      setState(() {
        _isSaving = false;
        _formError = 'Could not save your profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Technician?>>(myTechnicianProfileProvider, (previous, next) {
      next.whenData((profile) {
        if (profile != null && mounted) setState(() => _prefillFrom(profile));
      });
    });

    final hasLocation = _capturedLatitude != null && _capturedLongitude != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trade Technician profile'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Get found for on-demand jobs',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Just enough to be found and contacted — no CV needed.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 24),
                    if (_prefilled) ...[
                      Builder(builder: (context) {
                        final profile =
                            ref.watch(myTechnicianProfileProvider).valueOrNull;
                        if (profile == null) return const SizedBox.shrink();
                        return Card(
                          margin: EdgeInsets.zero,
                          child: SwitchListTile.adaptive(
                            title: const Text('Available for jobs'),
                            subtitle: Text(
                              profile.availabilityStatus
                                  ? 'Showing up in nearby searches'
                                  : 'Hidden from nearby searches',
                            ),
                            value: profile.availabilityStatus,
                            onChanged: (value) async {
                              try {
                                await ref
                                    .read(myTechnicianProfileProvider.notifier)
                                    .toggleAvailability(value);
                              } catch (_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Could not update availability. Please try again.'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    if (_formError != null) ...[
                      _ErrorBanner(message: _formError!),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) => (value == null || value.trim().length < 2)
                          ? 'Enter at least 2 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _tradeCategory,
                      decoration: const InputDecoration(labelText: 'Trade'),
                      items: [
                        for (final trade in kExpertTradeCategories)
                          DropdownMenuItem(value: trade.key, child: Text(trade.label)),
                      ],
                      onChanged: (value) => setState(() => _tradeCategory = value),
                      validator: (value) => value == null ? 'Choose a trade' : null,
                    ),
                    const SizedBox(height: 16),
                    Text('Skills', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _skillInputController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Wiring, AC repair',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addSkill(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _addSkill, child: const Text('Add')),
                      ],
                    ),
                    if (_skills.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final skill in _skills)
                            Chip(
                              label: Text(skill),
                              visualDensity: VisualDensity.compact,
                              onDeleted: () => setState(() => _skills.remove(skill)),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Rate (optional)', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rateAmountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount (ETB)',
                              isDense: true,
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<TechnicianRateUnit>(
                            initialValue: _rateUnit,
                            decoration: const InputDecoration(
                              labelText: 'Billed',
                              isDense: true,
                            ),
                            items: [
                              for (final unit in TechnicianRateUnit.values)
                                DropdownMenuItem(value: unit, child: Text(unit.label)),
                            ],
                            onChanged: (value) => setState(() => _rateUnit = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Location', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasLocation ? Icons.check_circle : Icons.location_off_outlined,
                            color: hasLocation ? AppColors.greenDark : AppColors.inkMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hasLocation
                                  ? 'Location captured — nearby customers can find you.'
                                  : 'Share your location so nearby customers can find you.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _isCapturingLocation ? null : _captureLocation,
                            child: _isCapturingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(hasLocation ? 'Update' : 'Capture'),
                          ),
                        ],
                      ),
                    ),
                    if (_locationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _locationError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
