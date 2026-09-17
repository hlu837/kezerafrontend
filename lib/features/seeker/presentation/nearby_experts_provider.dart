import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/device_location_service.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/technician_repository.dart';
import '../domain/technician.dart';

/// Where the current search center came from — the map screen shows a
/// different hint ("Showing technicians near your location" vs "near
/// Addis Ababa") depending on which.
enum NearbySearchOrigin { device, manual }

final technicianRepositoryProvider = Provider<TechnicianRepository>((ref) {
  return TechnicianRepository(ref.watch(apiClientProvider));
});

/// "Find a technician near you" — bundles the active search center/
/// filters with the async result, same `params` + `AsyncValue<r>` shape
/// as `PublicCandidatesState` (public_candidates_provider.dart), just
/// for `GET /technicians/nearby` instead of `/public-search`.
///
/// Phase 4 of the Expert/Technician split (see Technician.model.js's
/// top-of-file note): this provider used to back `GET /seekers/nearby`
/// against `Seeker` data; it's now repointed at the dedicated
/// `Technician` collection/endpoints instead — the map/list UI itself
/// (nearby_experts_map_screen.dart) is unchanged in shape, just fed
/// from a different source.
class NearbyExpertsState {
  const NearbyExpertsState({
    required this.params,
    required this.result,
    required this.origin,
    this.manualLocationLabel,
  });

  final NearbyTechniciansParams? params;
  final AsyncValue<NearbyTechniciansResult> result;
  final NearbySearchOrigin origin;
  // Display name of the place the person searched/picked (e.g. "Bole") —
  // only meaningful when `origin == NearbySearchOrigin.manual`. Null for
  // a plain lat/lng manual center with no place name attached.
  final String? manualLocationLabel;

  NearbyExpertsState copyWith({
    NearbyTechniciansParams? params,
    AsyncValue<NearbyTechniciansResult>? result,
    NearbySearchOrigin? origin,
    String? manualLocationLabel,
    bool clearManualLocationLabel = false,
  }) =>
      NearbyExpertsState(
        params: params ?? this.params,
        result: result ?? this.result,
        origin: origin ?? this.origin,
        manualLocationLabel: clearManualLocationLabel
            ? null
            : (manualLocationLabel ?? this.manualLocationLabel),
      );
}

/// Keyed by the trade category (e.g. 'electrician') the search should
/// start filtered to — `null` for "any trade". Set once, from whichever
/// card the person tapped on [ExpertCategoriesScreen] (or `null` when
/// they opened the map directly via "View nearby experts on map").
final nearbyExpertsProvider = StateNotifierProvider.autoDispose
    .family<NearbyExpertsNotifier, NearbyExpertsState, String?>((ref, initialTrade) {
  return NearbyExpertsNotifier(
    ref.watch(technicianRepositoryProvider),
    const DeviceLocationService(),
    initialTrade: initialTrade,
  );
});

class NearbyExpertsNotifier extends StateNotifier<NearbyExpertsState> {
  NearbyExpertsNotifier(
    this._repository,
    this._locationService, {
    String? initialTrade,
  })  : _initialTrade = initialTrade,
        super(
          const NearbyExpertsState(
            params: null,
            result: AsyncValue.loading(),
            origin: NearbySearchOrigin.device,
          ),
        ) {
    // Auto-attempt device GPS on first open — if it's denied/unavailable
    // the screen falls into an explicit "search a place instead" state
    // rather than an endless spinner (see result's AsyncValue.error).
    useDeviceLocation();
  }

  final TechnicianRepository _repository;
  final DeviceLocationService _locationService;
  // Applied only to the very first search this notifier runs (see
  // useDeviceLocation/searchLocation below) — after that, `trade` lives
  // on `state.params` like every other filter, and `updateFilters`
  // controls it from there.
  final String? _initialTrade;

  /// Centers the search on the device's current GPS fix. Throws (via the
  /// resulting `AsyncValue.error`) a [DeviceLocationException] on
  /// failure so the screen can show a specific, actionable message
  /// ("turn on location services" vs "allow location access").
  Future<void> useDeviceLocation() async {
    state = state.copyWith(
      result: const AsyncValue.loading(),
      origin: NearbySearchOrigin.device,
      clearManualLocationLabel: true,
    );
    try {
      final position = await _locationService.getCurrentLatLng();
      await _run(
        NearbyTechniciansParams(
          latitude: position.latitude,
          longitude: position.longitude,
          trade: state.params?.trade ?? _initialTrade,
        ),
      );
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }

  /// Centers the search on a manually-chosen point — e.g. a place the
  /// person searched or a pin they dropped on the map — instead of the
  /// device's own GPS fix. [label] is the place's display name (e.g.
  /// "Bole"), shown by the map screen's filter bar in place of the
  /// generic "near the selected point"; omit it for a plain coordinate
  /// with no associated name.
  Future<void> searchLocation({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    state = state.copyWith(
      origin: NearbySearchOrigin.manual,
      manualLocationLabel: label,
      clearManualLocationLabel: label == null,
    );
    return _run(NearbyTechniciansParams(
      latitude: latitude,
      longitude: longitude,
      trade: state.params?.trade ?? _initialTrade,
    ));
  }

  /// Re-runs the current search with a different radius/skill/trade
  /// filter, keeping whatever center point is already active.
  Future<void> updateFilters({
    double? radiusKm,
    List<String>? skills,
    String? trade,
    bool clearTrade = false,
  }) {
    final current = state.params;
    if (current == null) return Future.value();
    return _run(
      current.copyWith(
        radiusKm: radiusKm,
        skills: skills,
        trade: trade,
        clearTrade: clearTrade,
      ),
    );
  }

  Future<void> _run(NearbyTechniciansParams params) async {
    state = state.copyWith(params: params, result: const AsyncValue.loading());
    try {
      final result = await _repository.nearbyTechnicians(params);
      state = state.copyWith(result: AsyncValue.data(result));
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }
}
