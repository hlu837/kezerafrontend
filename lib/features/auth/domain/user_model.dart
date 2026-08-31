import 'package:equatable/equatable.dart';

/// Mirrors the backend's `src/models/User.model.js` roles.
enum UserRole { seeker, employer, agency, admin }

UserRole userRoleFromString(String value) => UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.seeker,
    );

/// Mirrors the backend's `verificationStatus` field.
enum VerificationStatus { paymentPending, pending, approved, rejected }

VerificationStatus verificationStatusFromString(String? value) {
  switch (value) {
    case 'payment_pending':
      return VerificationStatus.paymentPending;
    case 'pending':
      return VerificationStatus.pending;
    case 'rejected':
      return VerificationStatus.rejected;
    default:
      return VerificationStatus.approved;
  }
}

/// Where each role lands after login — the Flutter equivalent of the web
/// backoffice's `ROLE_DASHBOARD_PATH`. Kept in one place so every entry
/// point (login, register, deep links, startup hydration) agrees on it.
extension UserRoleRouting on UserRole {
  String get dashboardPath {
    switch (this) {
      case UserRole.seeker:
        return '/seeker/dashboard';
      case UserRole.employer:
        return '/employer/dashboard';
      case UserRole.agency:
        return '/agency/dashboard';
      case UserRole.admin:
        return '/admin/dashboard';
    }
  }
}

/// Mirrors `src/models/User.model.js` `toJSON()` output from the backend.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.verificationStatus = VerificationStatus.approved,
    this.verificationRejectionReason,
  });

  final String id;
  final String? phone;
  final String? email;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VerificationStatus verificationStatus;
  final String? verificationRejectionReason;

  bool get isPaymentPending => verificationStatus == VerificationStatus.paymentPending;
  bool get isPending => verificationStatus == VerificationStatus.pending;
  bool get isRejected => verificationStatus == VerificationStatus.rejected;
  bool get isApproved => verificationStatus == VerificationStatus.approved;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        role: userRoleFromString(json['role'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        verificationStatus:
            verificationStatusFromString(json['verificationStatus'] as String?),
        verificationRejectionReason:
            json['verificationRejectionReason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'verificationStatus': verificationStatus.name,
        'verificationRejectionReason': verificationRejectionReason,
      };

  @override
  List<Object?> get props => [
        id,
        phone,
        email,
        role,
        createdAt,
        updatedAt,
        verificationStatus,
        verificationRejectionReason,
      ];
}
