import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// One match returned by a place-name search — e.g. searching "Bole"
/// might return a few candidates ("Bole", "Bole Road", "Bole Atlas") for
/// the person to pick from, same "search returns several candidates"
/// shape as any address-autocomplete UI.
class GeocodedPlace {
  const GeocodedPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

/// Why a place search failed — lets the search sheet show something
/// actionable instead of a generic "something went wrong", same
/// reasoning as [DeviceLocationFailure] one level up.
enum GeocodingFailure {
  /// [AppConstants.gebetaMapsApiKey] is blank — same "feature quietly
  /// unavailable without a key" state the map view itself falls into.
  missingApiKey,

  /// The request went out but failed (offline, timeout, non-2xx, ...).
  requestFailed,

  /// The request succeeded but matched no places.
  noResults,
}

class GeocodingException implements Exception {
  const GeocodingException(this.reason);
  final GeocodingFailure reason;
}

/// Thin wrapper around Gebeta Maps' forward-geocoding endpoint
/// (docs.gebeta.app/docs/geocoding/geocoding-foward) — turns a typed
/// place name ("Bole") into candidate coordinates, so the nearby-experts/
/// nearby-agencies map screens have a manual fallback when device GPS is
/// off or denied. Deliberately a separate, unauthenticated [Dio] instance
/// from [ApiClient] (core/network/api_client.dart): this hits Gebeta's
/// own API host with its own API key, not this app's backend.
class GebetaGeocodingService {
  const GebetaGeocodingService();

  static const _baseUrl = 'https://mapapi.gebeta.app/api/v1/route';

  /// Searches for places matching [query] (a place/neighborhood name,
  /// e.g. "Bole"). Returns the best matches, nearest/most-relevant first
  /// per Gebeta's own ranking.
  ///
  /// NOTE ON RESPONSE SHAPE: Gebeta's public docs show the request but
  /// not a full sample response body. This parses the reasonably-likely
  /// shapes (a bare array, or `{ "data": [...] }`/`{ "results": [...] }`,
  /// with each place exposing either `latitude`/`longitude` or the
  /// shorter `lat`/`lon`, and a `name` field) and throws
  /// [GeocodingFailure.requestFailed] if none of those match. If your
  /// account's response looks different once you test it against a real
  /// API key, adjust `_parsePlaces` below rather than the call sites —
  /// same "one seam to fix" approach as the map style URL's auth
  /// comment in nearby_experts_map_screen.dart.
  Future<List<GeocodedPlace>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final apiKey = AppConstants.gebetaMapsApiKey;
    if (apiKey.isEmpty) {
      throw const GeocodingException(GeocodingFailure.missingApiKey);
    }

    final Response<dynamic> response;
    try {
      response = await Dio().get<dynamic>(
        '$_baseUrl/geocoding',
        queryParameters: {'name': trimmed, 'apiKey': apiKey},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
    } catch (_) {
      throw const GeocodingException(GeocodingFailure.requestFailed);
    }

    final places = _parsePlaces(response.data);
    if (places.isEmpty) {
      throw const GeocodingException(GeocodingFailure.noResults);
    }
    return places;
  }

  List<GeocodedPlace> _parsePlaces(dynamic body) {
    final rawList = switch (body) {
      List<dynamic> list => list,
      {'data': List<dynamic> list} => list,
      {'results': List<dynamic> list} => list,
      _ => const <dynamic>[],
    };

    final places = <GeocodedPlace>[];
    for (final raw in rawList) {
      if (raw is! Map) continue;
      final entry = raw.cast<String, dynamic>();

      final lat = _numField(entry, ['latitude', 'lat']);
      final lon = _numField(entry, ['longitude', 'lon', 'lng']);
      if (lat == null || lon == null) continue;

      final name = entry['name'] as String? ??
          entry['address'] as String? ??
          entry['title'] as String? ??
          _fallbackPlaceName;
      places.add(GeocodedPlace(name: name, latitude: lat, longitude: lon));
    }
    return places;
  }

  double? _numField(Map<String, dynamic> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static const _fallbackPlaceName = 'Unnamed place';
}
