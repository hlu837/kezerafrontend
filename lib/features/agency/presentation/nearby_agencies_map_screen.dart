import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/location/device_location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/call_text_buttons.dart';
import '../../../core/widgets/place_search_sheet.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/auth_state.dart';
import '../../service_requests/domain/service_request.dart';
import '../../service_requests/presentation/request_service_sheet.dart';
import '../domain/agency_comment.dart';
import 'agency_profile_screen.dart';
import 'nearby_agencies_provider.dart';

/// Shared avatar for an agency row/pin-preview — the agency's logo when
/// it has one, falling back to an initials circle. Mirrors
/// `_ExpertAvatar` (seeker/presentation/nearby_experts_map_screen.dart).
class _AgencyAvatar extends StatelessWidget {
  const _AgencyAvatar({required this.agency, this.radius = 20});

  final NearbyAgency agency;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final logoUrl = agency.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.greenSurface,
        backgroundImage: NetworkImage(logoUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.greenSurface,
      child: Text(
        agency.agencyName.isNotEmpty ? agency.agencyName[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppColors.greenDark,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// "Find agencies near you" — the guest-facing map/list for locating a
/// recruitment agency close to a given point, backed by
/// `GET /agencies/nearby`. Reachable via `NearbyMapScreen`'s Agencies
/// mode (that screen owns the shared Scaffold/AppBar and the
/// Experts/Agencies toggle; this widget is just the embedded body for
/// the Agencies side).
///
/// Structurally a straight mirror of `NearbyExpertsMapScreen` — see
/// that file for the fuller rationale on the map/list split and the
/// Gebeta style-URL setup — just plotting agencies (with their open-job
/// count) instead of individual skilled seekers, and with no trade
/// filter (agencies don't have one).
class NearbyAgenciesMapScreen extends ConsumerStatefulWidget {
  const NearbyAgenciesMapScreen({super.key});

  @override
  ConsumerState<NearbyAgenciesMapScreen> createState() =>
      _NearbyAgenciesMapScreenState();
}

class _NearbyAgenciesMapScreenState extends ConsumerState<NearbyAgenciesMapScreen> {
  GebetaMapController? _mapController;
  final List<Circle> _circles = [];
  final Map<String, NearbyAgency> _circleAgencies = {};

  String get _styleUrl =>
      'https://tiles.gebeta.app/styles/standard/style.json'
      '?apiKey=${AppConstants.gebetaMapsApiKey}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyAgenciesProvider);

    ref.listen(nearbyAgenciesProvider, (previous, next) {
      next.result.whenData((result) => _syncMapPins(next, result));
    });

    // No own Scaffold/AppBar — embedded inside `NearbyMapScreen`'s
    // shared Scaffold (see that file's doc comment on
    // `NearbyExpertsMapScreen` for why this is safe for
    // ScaffoldMessenger usage below).
    return Column(
      children: [
        _RadiusBar(state: state),
        const Divider(height: 1),
        Expanded(
          flex: 3,
          child: state.params == null
              ? const SizedBox.shrink()
              : GebetaMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(state.params!.latitude, state.params!.longitude),
                    zoom: 12,
                  ),
                  styleString: _styleUrl,
                  myLocationEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    state.result.whenData(
                      (result) => _syncMapPins(state, result),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: state.result.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _NearbyAgenciesErrorState(
              error: error,
              onUseDeviceLocation: () =>
                  ref.read(nearbyAgenciesProvider.notifier).useDeviceLocation(),
              onSearchPlace: () async {
                final place = await showPlaceSearchSheet(context);
                if (place == null) return;
                await ref.read(nearbyAgenciesProvider.notifier).searchLocation(
                      latitude: place.latitude,
                      longitude: place.longitude,
                      label: place.name,
                    );
              },
            ),
            data: (result) => _NearbyAgenciesResultList(result: result),
          ),
        ),
      ],
    );
  }

  Future<void> _syncMapPins(
    NearbyAgenciesState state,
    NearbyAgenciesResult result,
  ) async {
    final controller = _mapController;
    if (controller == null || state.params == null) return;

    for (final circle in _circles) {
      await controller.removeCircle(circle);
    }
    _circles.clear();
    _circleAgencies.clear();

    final centerCircle = await controller.addCircle(
      CircleOptions(
        geometry: LatLng(state.params!.latitude, state.params!.longitude),
        circleRadius: 9,
        circleColor: '#2563EB',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );
    _circles.add(centerCircle);

    for (final agency in result.agencies) {
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(agency.latitude, agency.longitude),
          circleRadius: 8,
          circleColor: '#F97316',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
      );
      _circles.add(circle);
      _circleAgencies[circle.id] = agency;
    }

    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onCircleTapped(Circle circle) {
    final agency = _circleAgencies[circle.id];
    if (agency == null || !mounted) return;
    _showAgencySheet(agency);
  }

  void _showAgencySheet(NearbyAgency agency) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _AgencyDetailSheet(agency: agency),
    );
  }

  @override
  void dispose() {
    _mapController?.onCircleTapped.remove(_onCircleTapped);
    super.dispose();
  }
}

class _RadiusBar extends ConsumerWidget {
  const _RadiusBar({required this.state});

  final NearbyAgenciesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(nearbyAgenciesProvider.notifier);
    final radiusKm = state.params?.radiusKm ?? 15;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              switch (state.origin) {
                NearbyAgenciesOrigin.device => 'Showing agencies near your location',
                NearbyAgenciesOrigin.manual when state.manualLocationLabel != null =>
                  'Showing agencies near ${state.manualLocationLabel}',
                NearbyAgenciesOrigin.manual => 'Showing agencies near the selected point',
              },
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<double>(
            value: radiusKm,
            underline: const SizedBox.shrink(),
            items: const [5, 10, 15, 25, 50]
                .map(
                  (km) => DropdownMenuItem(
                    value: km.toDouble(),
                    child: Text('${km}km'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              notifier.updateFilters(radiusKm: value);
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Search a place instead (e.g. Bole)',
            icon: const Icon(Icons.search),
            onPressed: () async {
              final place = await showPlaceSearchSheet(context);
              if (place == null) return;
              await notifier.searchLocation(
                latitude: place.latitude,
                longitude: place.longitude,
                label: place.name,
              );
            },
          ),
          IconButton(
            tooltip: 'Use my current location',
            icon: const Icon(Icons.my_location),
            onPressed: () => notifier.useDeviceLocation(),
          ),
        ],
      ),
    );
  }
}

class _NearbyAgenciesResultList extends StatelessWidget {
  const _NearbyAgenciesResultList({required this.result});

  final NearbyAgenciesResult result;

  @override
  Widget build(BuildContext context) {
    if (result.agencies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No agencies found within ${result.radiusKm.toStringAsFixed(0)}km. '
            'Try a wider radius.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: result.agencies.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _NearbyAgencyRow(agency: result.agencies[index]),
    );
  }
}

class _NearbyAgencyRow extends StatelessWidget {
  const _NearbyAgencyRow({required this.agency});

  final NearbyAgency agency;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (context) => _AgencyDetailSheet(agency: agency),
      ),
      leading: _AgencyAvatar(agency: agency),
      title: Text(agency.agencyName),
      subtitle: Text(
        '${agency.openJobsCount} open role${agency.openJobsCount == 1 ? '' : 's'}'
        '${agency.operationalCity != null ? ' · ${agency.operationalCity}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${agency.distanceKm.toStringAsFixed(1)} km',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

class _AgencyDetailSheet extends ConsumerWidget {
  const _AgencyDetailSheet({required this.agency});

  final NearbyAgency agency;

  /// "Request Service" — books a one-off job straight from this
  /// agency's map profile via `POST /service-requests`. Open to any
  /// signed-in account; a guest is sent to sign in first, since the
  /// endpoint requires an authenticated, approved account server-side
  /// regardless of what the client shows. Mirrors
  /// `nearby_experts_map_screen.dart`'s `_onRequestService`.
  Future<void> _onRequestService(BuildContext context, WidgetRef ref) async {
    final authStatus = ref.read(authProvider).status;
    if (authStatus != AuthStatus.authenticated) {
      Navigator.of(context).pop(); // close this sheet
      context.go('/login');
      return;
    }

    final submitted = await showRequestServiceSheet(
      context,
      targetType: ServiceRequestTargetType.agency,
      targetId: agency.id,
    );
    if (submitted == true && context.mounted) {
      Navigator.of(context).pop(); // close this sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${agency.agencyName}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AgencyAvatar(agency: agency, radius: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agency.agencyName, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${agency.distanceKm.toStringAsFixed(1)} km away'
                        '${agency.operationalCity != null ? ' · ${agency.operationalCity}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (agency.bio != null && agency.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(agency.bio!),
            ],
            if (agency.address != null && agency.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined,
                      size: 16, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      agency.address!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Four quick actions: Call and Text degrade to nothing when
            // the agency hasn't set a backofficePhone (see
            // CallTextButtons), Directions always works off the pin's
            // own coordinates, and View profile is always available.
            CallTextButtons(phone: agency.backofficePhone),
            if (agency.backofficePhone != null && agency.backofficePhone!.isNotEmpty)
              const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _onRequestService(context, ref),
                icon: const Icon(Icons.handyman_outlined, size: 18),
                label: const Text('Request Service'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchDirections(agency),
                icon: const Icon(Icons.directions_outlined, size: 18),
                label: const Text('Directions'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AgencyProfileScreen(
                        agencyId: agency.id,
                        agencyName: agency.agencyName,
                      ),
                    ),
                  );
                },
                child: Text('View profile · ${agency.openJobsCount} open roles'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDirections(NearbyAgency agency) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${agency.latitude},${agency.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Mirrors `_NearbyErrorState` (seeker/presentation/nearby_experts_map_screen.dart).
class _NearbyAgenciesErrorState extends StatelessWidget {
  const _NearbyAgenciesErrorState({
    required this.error,
    required this.onUseDeviceLocation,
    required this.onSearchPlace,
  });

  final Object error;
  final VoidCallback onUseDeviceLocation;
  final VoidCallback onSearchPlace;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      DeviceLocationException(reason: DeviceLocationFailure.servicesDisabled) =>
        'Location services are turned off on this device. Turn them on, or '
            'search for a place instead, to find agencies near you.',
      DeviceLocationException(reason: DeviceLocationFailure.permissionDenied) =>
        'Location access was declined. Allow it, or search for a place '
            'instead, to find agencies near you.',
      DeviceLocationException(
        reason: DeviceLocationFailure.permissionDeniedForever
      ) =>
        'Location access is blocked for this app. Enable it from your '
            "device's Settings, or search for a place instead, to find "
            'agencies near you.',
      DeviceLocationException(reason: DeviceLocationFailure.positionUnavailable) =>
        "Couldn't get your current location. Try again, or search for a "
            'place instead.',
      ApiException(:final message) => message,
      _ => 'Something went wrong loading nearby agencies.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: onUseDeviceLocation,
                  child: const Text('Try again'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onSearchPlace,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search a place'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
