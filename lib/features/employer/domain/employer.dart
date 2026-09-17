import 'package:equatable/equatable.dart';

import '../../seeker/domain/seeker.dart' show SubscriptionTier;

/// Mirrors `src/models/Employer.model.js`'s `toJSON()` output. Analogous
/// to `Seeker` (features/seeker/domain/seeker.dart) — one profile
/// document per employer user, fetched/edited via `EmployerRepository`.
class Employer extends Equatable {
  const Employer({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.createdAt,
    required this.updatedAt,
    this.logoUrl,
    this.backofficePhone,
    this.promoDetails,
    this.tinNumber,
    this.businessLicenseUrl,
    this.subscriptionTier = SubscriptionTier.basic,
  });

  final String id;
  final String userId;
  final String companyName;
  final String? logoUrl;
  final String? backofficePhone;
  final String? promoDetails;
  // Verification-time fields — set at registration, not editable from the
  // account screen (see employer.validator.js's updateProfileSchema,
  // which only accepts company_name/backoffice_phone/promo_details).
  final String? tinNumber;
  final String? businessLicenseUrl;
  final SubscriptionTier subscriptionTier;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Employer.fromJson(Map<String, dynamic> json) => Employer(
        id: json['id'] as String,
        userId: json['userId'] as String,
        companyName: json['companyName'] as String,
        logoUrl: json['logoUrl'] as String?,
        backofficePhone: json['backofficePhone'] as String?,
        promoDetails: json['promoDetails'] as String?,
        tinNumber: json['tinNumber'] as String?,
        businessLicenseUrl: json['businessLicenseUrl'] as String?,
        subscriptionTier:
            SubscriptionTier.fromWire(json['subscriptionTier'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Employer copyWith({
    String? companyName,
    String? logoUrl,
    String? backofficePhone,
    String? promoDetails,
    DateTime? updatedAt,
  }) =>
      Employer(
        id: id,
        userId: userId,
        companyName: companyName ?? this.companyName,
        logoUrl: logoUrl ?? this.logoUrl,
        backofficePhone: backofficePhone ?? this.backofficePhone,
        promoDetails: promoDetails ?? this.promoDetails,
        tinNumber: tinNumber,
        businessLicenseUrl: businessLicenseUrl,
        subscriptionTier: subscriptionTier,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        companyName,
        logoUrl,
        backofficePhone,
        promoDetails,
        tinNumber,
        businessLicenseUrl,
        subscriptionTier,
        createdAt,
        updatedAt,
      ];
}
