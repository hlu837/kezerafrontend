import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/device_location_service.dart';
import '../data/agency_comments_repository.dart';
import '../domain/agency_comment.dart';
import 'agency_comments_provider.dart' show agencyCommentsRepositoryProvider;

/// Where the current search center came from — mirrors
/// `NearbySearchOrigin` (seeker/presentation/nearby_experts_provider.dart).
enum NearbyAgenciesOrigin { device, manual }

/// "Find agencies near you" — bundles the active search center with the
/// async result, same `params` + `AsyncValue<result>` shape as
/// `NearbyExpertsState`, just for `GET /agencies/nearby`.
class NearbyAgenciesState {
  const NearbyAgenciesState({
    required this.params,
    required this.result,
    required this.origin,
    this.manualLocationLabel,
  });

  final NearbyAgenciesParams? params;
  final AsyncValue<NearbyAgenciesResult> result;
  final NearbyAgenciesOrigin origin;
  // Mirrors NearbyExpertsState.manualLocationLabel — see that doc comment.
  final String? manualLocationLabel;

  NearbyAgenciesState copyWith({
    NearbyAgenciesParams? params,
    AsyncValue<NearbyAgenciesResult>? result,
    NearbyAgenciesOrigin? origin,
    String? manualLocationLabel,
    bool clearManualLocationLabel = false,
  }) =>
      NearbyAgenciesState(
        params: params ?? this.params,
        result: result ?? this.result,
        origin: origin ?? this.origin,
        manualLocationLabel: clearManualLocationLabel
            ? null
            : (manualLocationLabel ?? this.manualLocationLabel),
      );
}

final nearbyAgenciesProvider =
    StateNotifierProvider.autoDispose<NearbyAgenciesNotifier, NearbyAgenciesState>((ref) {
  return NearbyAgenciesNotifier(
    ref.watch(agencyCommentsRepositoryProvider),
    const DeviceLocationService(),
  );
});

class NearbyAgenciesNotifier extends StateNotifier<NearbyAgenciesState> {
  NearbyAgenciesNotifier(this._repository, this._locationService)
      : super(
          const NearbyAgenciesState(
            params: null,
            result: AsyncValue.loading(),
            origin: NearbyAgenciesOrigin.device,
          ),
        ) {
    // Auto-attempt device GPS on first open, same reasoning as
    // NearbyExpertsNotifier — falls into an explicit error state
    // (rather than an endless spinner) if denied/unavailable.
    useDeviceLocation();
  }

  final AgencyCommentsRepository _repository;
  final DeviceLocationService _locationService;

  Future<void> useDeviceLocation() async {
    state = state.copyWith(
      result: const AsyncValue.loading(),
      origin: NearbyAgenciesOrigin.device,
      clearManualLocationLabel: true,
    );
    try {
      final position = await _locationService.getCurrentLatLng();
      await _run(NearbyAgenciesParams(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: state.params?.radiusKm ?? 15,
      ));
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }

  /// Centers the search on a manually-chosen point instead of the
  /// device's own GPS fix — e.g. a place typed into a search box. See
  /// NearbyExpertsNotifier.searchLocation's doc comment for [label].
  Future<void> searchLocation({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    state = state.copyWith(
      origin: NearbyAgenciesOrigin.manual,
      manualLocationLabel: label,
      clearManualLocationLabel: label == null,
    );
    return _run(NearbyAgenciesParams(
      latitude: latitude,
      longitude: longitude,
      radiusKm: state.params?.radiusKm ?? 15,
    ));
  }

  Future<void> updateFilters({double? radiusKm}) {
    final current = state.params;
    if (current == null) return Future.value();
    return _run(current.copyWith(radiusKm: radiusKm));
  }

  Future<void> _run(NearbyAgenciesParams params) async {
    state = state.copyWith(params: params, result: const AsyncValue.loading());
    try {
      final result = await _repository.fetchNearbyAgencies(params);
      state = state.copyWith(result: AsyncValue.data(result));
    } catch (error, stackTrace) {
      state = state.copyWith(result: AsyncValue.error(error, stackTrace));
    }
  }
}
