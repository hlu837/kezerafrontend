import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/location/device_location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/auth_state.dart';
import '../../../core/widgets/place_search_sheet.dart';
import '../../service_requests/domain/service_request.dart';
import '../../service_requests/presentation/request_service_sheet.dart';
import '../domain/expert_trade_category.dart';
import '../domain/technician.dart';
import 'nearby_experts_provider.dart';

/// Shared avatar for a technician row/sheet — a network photo when the
/// technician has one, falling back to the initials circle everywhere
/// else in this file already used before photoUrl was exposed on
/// `/nearby`.
class _ExpertAvatar extends StatelessWidget {
  const _ExpertAvatar({required this.technician, this.radius = 20});

  final Technician technician;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = technician.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.greenSurface,
        backgroundImage: NetworkImage(photoUrl),
        // If the image fails to load, fall back to initials rather than
        // a broken-image icon — onBackgroundImageError doesn't let us
        // swap the child, so this errorBuilder-less approach relies on
        // NetworkImage's own retry/placeholder behavior being enough;
        // a blank circle is an acceptable degrade either way.
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.greenSurface,
      child: Text(
        technician.fullName.isNotEmpty ? technician.fullName[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppColors.greenDark,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// "Find a technician near you" — the guest-facing map/list for locating
/// a Trade Technician (electrician, plumber, etc.) close to a given
/// point, backed by `GET /technicians/nearby`. Reachable via
/// `NearbyMapScreen`'s Experts mode (see core/widgets — that screen
/// owns the shared Scaffold/AppBar and the Experts/Agencies toggle;
/// this widget is just the embedded body for the Experts side).
///
/// Renders a Gebeta Maps view with a pin per nearby technician (green
/// circles, sized/tap-to-preview) plus a scrollable list underneath, so
/// someone who'd rather scan names than tap pins still gets a full,
/// distance-sorted view of the same results.
///
/// Phase 4 of the Expert/Technician split (see Technician.model.js's
/// top-of-file note): this screen used to render `Seeker` data off
/// `GET /seekers/nearby`; it's now repointed at the dedicated
/// `Technician` collection/endpoints instead. The two CV-specific
/// actions the old sheet had — "Send Job Request" and "Chat" (both
/// `Placement`/`Job`-based, i.e. formal-hiring concepts that assume the
/// target has a CV) — are dropped here rather than carried over, since
/// neither concept applies to a Technician profile. "Request Service"
/// (a standalone booking, no job posting required — see
/// `ServiceRequest.model.js`) is the one action that already fit a
/// Technician, and is now the sheet's only CTA.
class NearbyExpertsMapScreen extends ConsumerStatefulWidget {
  const NearbyExpertsMapScreen({super.key, this.initialTrade});

  /// The trade category (e.g. 'electrician') to start filtered to, when
  /// this screen was reached by tapping a card on the "Experts"
  /// directory (see `/experts/nearby?trade=...` in app_router.dart).
  /// `null` when reached directly (any trade).
  final String? initialTrade;

  @override
  ConsumerState<NearbyExpertsMapScreen> createState() =>
      _NearbyExpertsMapScreenState();
}

class _NearbyExpertsMapScreenState
    extends ConsumerState<NearbyExpertsMapScreen> {
  GebetaMapController? _mapController;
  // Keeps every circle this screen has added so a fresh search can clear
  // them out cleanly instead of pins from a previous search lingering
  // alongside the new ones.
  final List<Circle> _circles = [];
  // Maps a circle's id back to the technician it represents, so tapping
  // a pin can show that technician's details instead of just its
  // coordinates.
  final Map<String, NearbyTechnician> _circleTechnicians = {};

  /// The style URL Gebeta's docs use for their hosted vector tiles
  /// (see docs.gebeta.app/docs/tiles/overview), with this project's API
  /// key attached the same way Gebeta's own REST endpoints accept one
  /// (?apiKey=...). If your Gebeta account instead requires the key as
  /// an `Authorization: Bearer` header on tile requests rather than a
  /// query param, swap this for `GebetaMap`'s `transformRequest`
  /// callback instead — see the gebeta_gl README's "Documentation"
  /// section for the current auth convention.
  String get _styleUrl =>
      'https://tiles.gebeta.app/styles/standard/style.json'
      '?apiKey=${AppConstants.gebetaMapsApiKey}';

  @override
  Widget build(BuildContext context) {
    final provider = nearbyExpertsProvider(widget.initialTrade);
    final state = ref.watch(provider);

    // Whenever the search result changes (new center, new filters),
    // re-plot the map's pins to match — the list below re-renders on
    // its own via the `watch` above, this just keeps the map in sync
    // too since the map's annotations live on the controller, not in
    // the widget tree.
    ref.listen(provider, (previous, next) {
      next.result.whenData((result) => _syncMapPins(next, result));
    });

    // No own Scaffold/AppBar here — this is embedded inside
    // `NearbyMapScreen`'s shared Scaffold now (see that file), which
    // supplies the AppBar and the Experts/Agencies mode toggle. A
    // `ScaffoldMessenger.of(context)` call anywhere below (e.g.
    // `_TechnicianDetailSheet`'s snackbars) still resolves fine — it
    // walks up to whichever Scaffold ancestor exists, regardless of
    // which widget in the tree is asking.
    return Column(
      children: [
        _FilterBar(state: state, providerArg: widget.initialTrade),
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
            error: (error, _) => _NearbyErrorState(
              error: error,
              onUseDeviceLocation: () =>
                  ref.read(provider.notifier).useDeviceLocation(),
              onSearchPlace: () async {
                final place = await showPlaceSearchSheet(context);
                if (place == null) return;
                await ref.read(provider.notifier).searchLocation(
                      latitude: place.latitude,
                      longitude: place.longitude,
                      label: place.name,
                    );
              },
            ),
            data: (result) => _NearbyResultList(result: result),
          ),
        ),
      ],
    );
  }

  Future<void> _syncMapPins(
    NearbyExpertsState state,
    NearbyTechniciansResult result,
  ) async {
    final controller = _mapController;
    if (controller == null || state.params == null) return;

    for (final circle in _circles) {
      await controller.removeCircle(circle);
    }
    _circles.clear();
    _circleTechnicians.clear();

    // The search center itself, in a distinct color, so it's clear at a
    // glance where "near you" is being measured from.
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

    for (final nearby in result.technicians) {
      final technician = nearby.technician;
      if (!technician.hasLocation) continue;
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(technician.latitude!, technician.longitude!),
          circleRadius: 8,
          circleColor: '#16A34A',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
      );
      _circles.add(circle);
      _circleTechnicians[circle.id] = nearby;
    }

    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onCircleTapped(Circle circle) {
    final nearby = _circleTechnicians[circle.id];
    if (nearby == null || !mounted) return;
    _showTechnicianSheet(nearby);
  }

  void _showTechnicianSheet(NearbyTechnician nearby) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _TechnicianDetailSheet(nearby: nearby),
    );
  }

  @override
  void dispose() {
    _mapController?.onCircleTapped.remove(_onCircleTapped);
    super.dispose();
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.state, required this.providerArg});

  final NearbyExpertsState state;

  /// The family key for `nearbyExpertsProvider` — same value as
  /// `NearbyExpertsMapScreen.initialTrade` — needed here since this is
  /// a separate `ConsumerWidget` that has to read/watch the same
  /// provider instance as its parent.
  final String? providerArg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(nearbyExpertsProvider(providerArg).notifier);
    final radiusKm = state.params?.radiusKm ?? 15;
    final selectedTrade = state.params?.trade;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  switch (state.origin) {
                    NearbySearchOrigin.device => 'Showing technicians near your location',
                    NearbySearchOrigin.manual when state.manualLocationLabel != null =>
                      'Showing technicians near ${state.manualLocationLabel}',
                    NearbySearchOrigin.manual => 'Showing technicians near the selected point',
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
          const SizedBox(height: 4),
          // Trade-category picker — same filter the "Experts" directory
          // (ExpertCategoriesScreen) sets via `initialTrade`, editable
          // here so someone who opened the map directly (or wants to
          // switch trades without leaving the map) can narrow/broaden
          // results without a round trip to the directory.
          SizedBox(
            width: double.infinity,
            child: DropdownButtonFormField<String?>(
              initialValue: selectedTrade,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Trade',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All trades')),
                for (final trade in kExpertTradeCategories)
                  DropdownMenuItem(value: trade.key, child: Text(trade.label)),
              ],
              onChanged: (value) => notifier.updateFilters(
                trade: value,
                clearTrade: value == null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyResultList extends StatelessWidget {
  const _NearbyResultList({required this.result});

  final NearbyTechniciansResult result;

  @override
  Widget build(BuildContext context) {
    if (result.technicians.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No technicians found within ${result.radiusKm.toStringAsFixed(0)}km. '
            'Try a wider radius.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Horizontal scroller of cards below the map (Uber/Airbnb-style
    // "results strip") instead of a vertical list — the map already
    // takes the top of the screen, so results scan left-to-right
    // beneath it rather than stacking down the page.
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      itemCount: result.technicians.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final nearby = result.technicians[index];
        return _NearbyExpertCard(nearby: nearby);
      },
    );
  }
}

class _NearbyExpertCard extends StatelessWidget {
  const _NearbyExpertCard({required this.nearby});

  final NearbyTechnician nearby;

  @override
  Widget build(BuildContext context) {
    final technician = nearby.technician;
    return SizedBox(
      width: 200,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (context) => _TechnicianDetailSheet(nearby: nearby),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _ExpertAvatar(technician: technician),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        technician.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  technician.skills.isNotEmpty
                      ? technician.skills.take(3).join(', ')
                      : 'No skills listed',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${nearby.distanceKm.toStringAsFixed(1)} km away',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    if (technician.formattedRate != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${technician.formattedRate}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TechnicianDetailSheet extends ConsumerStatefulWidget {
  const _TechnicianDetailSheet({required this.nearby});

  final NearbyTechnician nearby;

  @override
  ConsumerState<_TechnicianDetailSheet> createState() => _TechnicianDetailSheetState();
}

class _TechnicianDetailSheetState extends ConsumerState<_TechnicianDetailSheet> {
  /// "Request Service" — books a one-off job straight from this
  /// technician's map profile via `POST /service-requests`, no job
  /// posting needed first (see `ServiceRequest.model.js`'s doc
  /// comment). Open to any signed-in account. A guest is sent to sign
  /// in first, since `POST /service-requests` requires an
  /// authenticated, approved account server-side regardless of what
  /// the client shows.
  Future<void> _onRequestService(BuildContext context) async {
    final authStatus = ref.read(authProvider).status;
    if (authStatus != AuthStatus.authenticated) {
      Navigator.of(context).pop(); // close this sheet
      context.go('/login');
      return;
    }

    final technician = widget.nearby.technician;
    final submitted = await showRequestServiceSheet(
      context,
      targetType: ServiceRequestTargetType.technician,
      targetId: technician.id,
      initialCategory: technician.tradeCategory,
    );
    if (submitted == true && mounted) {
      Navigator.of(context).pop(); // close this sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${technician.fullName}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearby = widget.nearby;
    final technician = nearby.technician;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ExpertAvatar(technician: technician, radius: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(technician.fullName, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${nearby.distanceKm.toStringAsFixed(1)} km away'
                        '${technician.city != null ? ' · ${technician.city}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (technician.formattedRate != null) ...[
              const SizedBox(height: 8),
              Text(
                technician.formattedRate!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.greenDark,
                    ),
              ),
            ],
            if (technician.skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in technician.skills)
                    Chip(label: Text(skill), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
            if (technician.bio != null && technician.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(technician.bio!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _onRequestService(context),
                icon: const Icon(Icons.handyman_outlined, size: 18),
                label: const Text('Request Service'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Distinguishes a location-permission problem (actionable — tell the
/// person how to fix it) from any other search failure (generic retry).
class _NearbyErrorState extends StatelessWidget {
  const _NearbyErrorState({
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
            'search for a place instead, to find technicians near you.',
      DeviceLocationException(reason: DeviceLocationFailure.permissionDenied) =>
        'Location access was declined. Allow it, or search for a place '
            'instead, to find technicians near you.',
      DeviceLocationException(
        reason: DeviceLocationFailure.permissionDeniedForever
      ) =>
        'Location access is blocked for this app. Enable it from your '
            "device's Settings, or search for a place instead, to find "
            'technicians near you.',
      DeviceLocationException(reason: DeviceLocationFailure.positionUnavailable) =>
        "Couldn't get your current location. Try again, or search for a "
            'place instead.',
      ApiException(:final message) => message,
      _ => 'Something went wrong loading nearby technicians.',
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
