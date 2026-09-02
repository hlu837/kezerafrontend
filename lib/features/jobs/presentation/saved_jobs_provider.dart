import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/job.dart';

/// The seeker's bookmarked jobs (the "Save" button on `_JobCard` /
/// `JobDetailScreen`, browsable on `SavedJobsScreen`). On-device only for
/// now — persisted via [SecureStorageService] as full `Job` snapshots
/// rather than a backend endpoint, so it doesn't sync across devices,
/// doesn't reflect the job's live status once saved, and survives only
/// as long as the app is installed. Swapping this for a real
/// `saved-jobs` API later only means rewriting this notifier; nothing
/// else in the UI needs to change.
///
/// Keyed by job id (insertion order preserved — Dart's default `Map` is
/// a `LinkedHashMap`) so `SavedJobsScreen` can show them in the order
/// they were saved, most recent last.
final savedJobsProvider =
    StateNotifierProvider<SavedJobsNotifier, Map<String, Job>>((ref) {
  return SavedJobsNotifier(ref.watch(secureStorageServiceProvider))..load();
});

class SavedJobsNotifier extends StateNotifier<Map<String, Job>> {
  SavedJobsNotifier(this._storage) : super(const {});

  final SecureStorageService _storage;

  Future<void> load() async {
    final raw = await _storage.readSavedJobsRaw();
    state = {
      for (final entry in raw) Job.fromJson(entry).id: Job.fromJson(entry),
    };
  }

  bool isSaved(String jobId) => state.containsKey(jobId);

  /// Flips [job]'s saved state and persists the result. Fire-and-forget
  /// on the write since the UI already reflects the new state optimistically
  /// via [state] — a save button shouldn't block on disk I/O.
  void toggle(Job job) {
    final next = Map<String, Job>.from(state);
    if (next.containsKey(job.id)) {
      next.remove(job.id);
    } else {
      next[job.id] = job;
    }
    state = next;
    _storage.saveSavedJobsRaw(next.values.map((j) => j.toJson()).toList());
  }

  /// Explicit remove, used by `SavedJobsScreen`'s "Remove" action — same
  /// effect as calling [toggle] on an already-saved job, just named for
  /// intent at the call site.
  void remove(String jobId) {
    if (!state.containsKey(jobId)) return;
    final next = Map<String, Job>.from(state)..remove(jobId);
    state = next;
    _storage.saveSavedJobsRaw(next.values.map((j) => j.toJson()).toList());
  }
}
