import 'package:equatable/equatable.dart';

/// Mirrors `src/models/Ad.model.js`'s `toJSON()` output and its
/// `AD_STATUSES` enum.
enum AdStatus {
  draft,
  pendingReview,
  active,
  rejected,
  expired;

  static AdStatus fromWire(String? value) {
    switch (value) {
      case 'pending_review':
        return AdStatus.pendingReview;
      case 'active':
        return AdStatus.active;
      case 'rejected':
        return AdStatus.rejected;
      case 'expired':
        return AdStatus.expired;
      case 'draft':
      default:
        return AdStatus.draft;
    }
  }

  /// Human-readable label for the status chip on `EmployerAdvertiseScreen`.
  String get label {
    switch (this) {
      case AdStatus.draft:
        return 'Draft — payment required';
      case AdStatus.pendingReview:
        return 'Pending review';
      case AdStatus.active:
        return 'Live';
      case AdStatus.rejected:
        return 'Rejected';
      case AdStatus.expired:
        return 'Expired';
    }
  }
}

/// One of the icon choices `Ad.model.js#AD_ICONS` accepts — kept as a
/// fixed enum here too so the "New ad" form can only submit a value the
/// backend actually allows.
enum AdIcon {
  campaign,
  workspacePremium,
  verified,
  cardGiftcard,
  storefront,
  localOffer,
  star,
  businessCenter;

  String get wireValue {
    switch (this) {
      case AdIcon.campaign:
        return 'campaign';
      case AdIcon.workspacePremium:
        return 'workspace_premium';
      case AdIcon.verified:
        return 'verified';
      case AdIcon.cardGiftcard:
        return 'card_giftcard';
      case AdIcon.storefront:
        return 'storefront';
      case AdIcon.localOffer:
        return 'local_offer';
      case AdIcon.star:
        return 'star';
      case AdIcon.businessCenter:
        return 'business_center';
    }
  }

  String get label {
    switch (this) {
      case AdIcon.campaign:
        return 'Megaphone';
      case AdIcon.workspacePremium:
        return 'Premium badge';
      case AdIcon.verified:
        return 'Verified check';
      case AdIcon.cardGiftcard:
        return 'Gift';
      case AdIcon.storefront:
        return 'Storefront';
      case AdIcon.localOffer:
        return 'Tag / offer';
      case AdIcon.star:
        return 'Star';
      case AdIcon.businessCenter:
        return 'Briefcase';
    }
  }
}

/// A single promoted ad belonging to the current employer/agency —
/// what `EmployerAdvertiseScreen` lists and what `AdsRepository.createAd`
/// returns.
class Ad extends Equatable {
  const Ad({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.createdAt,
    this.linkUrl,
    this.expiresAt,
    this.rejectionReason,
  });

  final String id;
  final String title;
  final String subtitle;
  final AdIcon icon;
  final AdStatus status;
  final String? linkUrl;
  final DateTime? expiresAt;
  final String? rejectionReason;
  final DateTime createdAt;

  factory Ad.fromJson(Map<String, dynamic> json) => Ad(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        icon: AdIcon.values.firstWhere(
          (i) => i.wireValue == json['icon'],
          orElse: () => AdIcon.campaign,
        ),
        status: AdStatus.fromWire(json['status'] as String?),
        linkUrl: json['linkUrl'] as String?,
        expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt'] as String) : null,
        rejectionReason: json['rejectionReason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props =>
      [id, title, subtitle, icon, status, linkUrl, expiresAt, rejectionReason, createdAt];
}
