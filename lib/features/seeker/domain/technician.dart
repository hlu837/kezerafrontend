import 'package:equatable/equatable.dart';

/// How a [Technician]'s rate is billed — mirrors `RATE_UNITS` on
/// `Technician.model.js`.
enum TechnicianRateUnit {
  hourly,
  daily,
  perJob;

  String get wireValue => switch (this) {
        TechnicianRateUnit.hourly => 'hourly',
        TechnicianRateUnit.daily => 'daily',
        TechnicianRateUnit.perJob => 'per_job',
      };

  String get label => switch (this) {
        TechnicianRateUnit.hourly => '/hr',
        TechnicianRateUnit.daily => '/day',
        TechnicianRateUnit.perJob => '/job',
      };

  static TechnicianRateUnit? fromWire(String? value) => switch (value) {
        'hourly' => TechnicianRateUnit.hourly,
        'daily' => TechnicianRateUnit.daily,
        'per_job' => TechnicianRateUnit.perJob,
        _ => null,
      };
}

/// Trade Expert / Technician Profile — the lightweight, on-demand
/// counterpart to [Seeker] (formal CV job seekers). Mirrors
/// `Technician.model.js`'s `toJSON()` output: name + trade + skills +
/// location + rate, no CV/experience/education. See that model's
/// top-of-file note for the full background on the Expert/Technician
/// split.
class Technician extends Equatable {
  const Technician({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.tradeCategory,
    required this.availabilityStatus,
    required this.createdAt,
    required this.updatedAt,
    this.skills = const [],
    this.bio,
    this.photoUrl,
    this.rateAmount,
    this.rateUnit,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String userId;
  final String fullName;
  final String tradeCategory;
  final List<String> skills;
  final String? bio;
  final String? photoUrl;
  final double? rateAmount;
  final TechnicianRateUnit? rateUnit;
  final String? city;
  final double? latitude;
  final double? longitude;
  final bool availabilityStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasLocation => latitude != null && longitude != null;

  Technician copyWith({bool? availabilityStatus}) => Technician(
        id: id,
        userId: userId,
        fullName: fullName,
        tradeCategory: tradeCategory,
        availabilityStatus: availabilityStatus ?? this.availabilityStatus,
        createdAt: createdAt,
        updatedAt: updatedAt,
        skills: skills,
        bio: bio,
        photoUrl: photoUrl,
        rateAmount: rateAmount,
        rateUnit: rateUnit,
        city: city,
        latitude: latitude,
        longitude: longitude,
      );

  /// e.g. "500 ETB/hr" — null when no rate is on file, so callers can
  /// decide whether to show a "Rate not listed" fallback instead.
  String? get formattedRate {
    final amount = rateAmount;
    final unit = rateUnit;
    if (amount == null || unit == null) return null;
    return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} ETB${unit.label}';
  }

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
        id: json['id'] as String,
        userId: json['userId'] as String,
        fullName: json['fullName'] as String,
        tradeCategory: json['tradeCategory'] as String,
        skills: (json['skills'] as List<dynamic>?)?.map((s) => s as String).toList() ??
            const [],
        bio: json['bio'] as String?,
        photoUrl: json['photoUrl'] as String?,
        rateAmount: (json['rateAmount'] as num?)?.toDouble(),
        rateUnit: TechnicianRateUnit.fromWire(json['rateUnit'] as String?),
        city: json['city'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        availabilityStatus: json['availabilityStatus'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        fullName,
        tradeCategory,
        skills,
        bio,
        photoUrl,
        rateAmount,
        rateUnit,
        city,
        latitude,
        longitude,
        availabilityStatus,
      ];
}

/// GET /technicians/nearby query params — "Find a technician near you".
/// Same shape as `NearbySeekersParams` (seeker.dart), minus the broad
/// `category` filter — a Technician profile has no
/// `Seeker.preferredCategories` equivalent, `trade` is its only
/// category axis (see nearbyTechniciansSchema on the backend).
class NearbyTechniciansParams {
  const NearbyTechniciansParams({
    required this.latitude,
    required this.longitude,
    this.radiusKm = 15,
    this.skills = const [],
    this.trade,
    this.limit = 50,
  });

  final double latitude;
  final double longitude;
  final double radiusKm;
  final List<String> skills;
  final String? trade;
  final int limit;

  Map<String, dynamic> toQuery() => {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        if (skills.isNotEmpty) 'skills': skills.join(','),
        if (trade != null && trade!.isNotEmpty) 'trade': trade,
        'limit': limit,
      };

  NearbyTechniciansParams copyWith({
    double? latitude,
    double? longitude,
    double? radiusKm,
    List<String>? skills,
    String? trade,
    bool clearTrade = false,
  }) =>
      NearbyTechniciansParams(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        radiusKm: radiusKm ?? this.radiusKm,
        skills: skills ?? this.skills,
        trade: clearTrade ? null : (trade ?? this.trade),
        limit: limit,
      );
}

/// One row of a `GET /technicians/nearby` response — a [Technician]
/// plus the straight-line distance (km) the backend computed from the
/// search center. Mirrors `NearbySeeker` (seeker.dart).
class NearbyTechnician {
  const NearbyTechnician({required this.technician, required this.distanceKm});

  final Technician technician;
  final double distanceKm;

  factory NearbyTechnician.fromJson(Map<String, dynamic> json) => NearbyTechnician(
        technician: Technician.fromJson(json),
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      );
}

class NearbyTechniciansResult {
  const NearbyTechniciansResult({
    required this.technicians,
    required this.count,
    required this.radiusKm,
  });

  final List<NearbyTechnician> technicians;
  final int count;
  final double radiusKm;

  factory NearbyTechniciansResult.fromJson(Map<String, dynamic> json) =>
      NearbyTechniciansResult(
        technicians: (json['technicians'] as List<dynamic>)
            .map((t) => NearbyTechnician.fromJson(t as Map<String, dynamic>))
            .toList(),
        count: json['count'] as int,
        radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 0,
      );
}
