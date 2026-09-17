import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/api_exception.dart';
import '../../../seeker/domain/job_category.dart';
import '../../../seeker/presentation/seeker_profile_provider.dart';

/// JS-06: the "For You" tab's category setup workflow — shown as a modal
/// sheet rather than a full-screen route so it can be triggered inline
/// from `JobBoardScreen` in two places:
///
///  1. Automatically, the first time an authenticated seeker opens the
///     "For You" tab with zero saved categories (see
///     `JobBoardScreen._maybeAutoPromptForCategories`).
///  2. On demand, via the "Edit preferences" icon in the tab's header,
///     pre-seeded with whatever's already saved.
///
/// Saves straight to `myProfileProvider` (same `PATCH
/// /seekers/me/preferences` endpoint `CategoryPreferencesScreen` uses for
/// onboarding) and pops with the newly-saved category list on success, so
/// the caller can splice it into `_forYouCategories` and re-run the feed
/// search immediately — nothing here talks to `jobBoardProvider` directly.
///
/// Mirrors `CategoryPreferencesScreen`'s "at least one category" rule:
/// the Save button stays disabled until one or more categories are
/// checked, matching the backend's own `updatePreferencesSchema` minimum.
class CategoryPreferencesSheet extends ConsumerStatefulWidget {
  const CategoryPreferencesSheet({
    super.key,
    required this.initialSelected,
    this.title = 'Personalize your "For You" feed',
    this.subtitle =
        'Select at least one category so we can show you jobs that '
        "actually match what you're looking for.",
  });

  final Set<String> initialSelected;
  final String title;
  final String subtitle;

  @override
  ConsumerState<CategoryPreferencesSheet> createState() =>
      _CategoryPreferencesSheetState();
}

class _CategoryPreferencesSheetState
    extends ConsumerState<CategoryPreferencesSheet> {
  late final Set<String> _selected = {...widget.initialSelected};
  bool _isSaving = false;
  String? _errorMessage;

  bool get _canSave => _selected.isNotEmpty && !_isSaving;

  void _toggle(String key, bool? checked) {
    setState(() {
      if (checked ?? false) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      // Preserve whatever `locationOptIn` is already on file — this sheet
      // only ever edits categories, so it shouldn't silently flip a
      // seeker's location-sharing choice back off in the process.
      final currentProfile = ref.read(myProfileProvider).valueOrNull;
      final updated = await ref.read(myProfileProvider.notifier).savePreferences(
            categories: _selected.toList(),
            locationOptIn: currentProfile?.locationOptIn ?? false,
          );
      if (mounted) Navigator.of(context).pop(updated.preferredCategories);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSaving = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Could not save your preferences. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    children: [
                      Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Theme.of(context).colorScheme.onErrorContainer, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      for (final category in kJobCategories)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selected.contains(category.key),
                          onChanged: _isSaving ? null : (checked) => _toggle(category.key, checked),
                          controlAffinity: ListTileControlAffinity.leading,
                          secondary: Icon(category.icon),
                          title: Text(category.label),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: FilledButton(
                      onPressed: _canSave ? _save : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_selected.isEmpty
                              ? 'Select at least 1 category'
                              : 'Save preferences'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Opens [CategoryPreferencesSheet] as a modal bottom sheet and returns
/// the newly-saved category list, or `null` if the sheet was dismissed
/// without saving (e.g. the seeker swiped it away).
Future<List<String>?> showCategoryPreferencesSheet(
  BuildContext context, {
  required Set<String> initialSelected,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    builder: (_) => CategoryPreferencesSheet(initialSelected: initialSelected),
  );
}
