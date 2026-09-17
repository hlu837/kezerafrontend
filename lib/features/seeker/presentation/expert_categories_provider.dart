import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nearby_experts_provider.dart' show technicianRepositoryProvider;
import '../domain/seeker.dart';

/// "Experts" directory landing page: `GET /technicians/trade-categories`,
/// every trade with how many currently-available technicians are listed
/// under it. Backs [ExpertCategoriesScreen]'s category cards.
///
/// Phase 4 of the Expert/Technician split: this used to read
/// `GET /seekers/trade-categories` (Seeker data); repointed at the
/// dedicated Technician collection/endpoint instead — see
/// nearby_experts_provider.dart's doc comment for the same note.
final expertCategoryCountsProvider =
    FutureProvider.autoDispose<List<ExpertCategoryCount>>((ref) {
  return ref.watch(technicianRepositoryProvider).tradeCategoryCounts();
});
