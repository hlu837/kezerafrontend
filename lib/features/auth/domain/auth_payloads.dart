/// POST /auth/login body. Backend accepts login via phone OR email.
class LoginPayload {
  LoginPayload({
    required this.password,
    this.phone,
    this.email,
  }) : assert(
          (phone != null && phone.isNotEmpty) ||
              (email != null && email.isNotEmpty),
          'Provide a phone or an email to log in.',
        );

  final String? phone;
  final String? email;
  final String password;

  /// Builds a [LoginPayload] from a single "phone or email" field, the way
  /// the web backoffice's login form does — anything containing `@` is
  /// treated as an email, everything else as a phone number.
  factory LoginPayload.fromIdentifier({
    required String identifier,
    required String password,
  }) {
    final trimmed = identifier.trim();
    final looksLikeEmail = trimmed.contains('@');
    return LoginPayload(
      password: password,
      phone: looksLikeEmail ? null : trimmed,
      email: looksLikeEmail ? trimmed : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
        'password': password,
      };
}

/// POST /auth/register body. The backend accepts three registerable roles
/// (admin accounts aren't self-service), each with its own required
/// fields on top of the shared `phone`/`password`/`email`. Mirrors the
/// web backoffice's `RegisterPayload` union in `src/types/auth.ts`, but
/// without a sealed-class/code-gen setup — factories + a role-keyed
/// `toJson` keep it just as safe to construct without adding a build step.
enum RegisterableRole { seeker, employer, agency }

class RegisterPayload {
  const RegisterPayload._({
    required this.role,
    required this.phone,
    required this.password,
    this.email,
    this.fullName,
    this.companyName,
    this.backofficePhone,
    this.promoDetails,
    this.agencyName,
    this.operationalCity,
    this.tinNumber,
    this.subscriptionTier,
  });

  factory RegisterPayload.seeker({
    required String phone,
    required String password,
    required String fullName,
    String? email,
  }) =>
      RegisterPayload._(
        role: RegisterableRole.seeker,
        phone: phone,
        password: password,
        email: email,
        fullName: fullName,
      );

  factory RegisterPayload.employer({
    required String phone,
    required String password,
    required String companyName,
    required String tinNumber,
    required String subscriptionTier,
    String? email,
    String? backofficePhone,
    String? promoDetails,
  }) =>
      RegisterPayload._(
        role: RegisterableRole.employer,
        phone: phone,
        password: password,
        email: email,
        companyName: companyName,
        backofficePhone: backofficePhone,
        promoDetails: promoDetails,
        tinNumber: tinNumber,
        subscriptionTier: subscriptionTier,
      );

  factory RegisterPayload.agency({
    required String phone,
    required String password,
    required String agencyName,
    required String tinNumber,
    required String subscriptionTier,
    String? email,
    String? operationalCity,
  }) =>
      RegisterPayload._(
        role: RegisterableRole.agency,
        phone: phone,
        password: password,
        email: email,
        agencyName: agencyName,
        operationalCity: operationalCity,
        tinNumber: tinNumber,
        subscriptionTier: subscriptionTier,
      );

  final RegisterableRole role;
  final String phone;
  final String password;
  final String? email;

  // seeker
  final String? fullName;
  // employer
  final String? companyName;
  final String? backofficePhone;
  final String? promoDetails;
  // agency
  final String? agencyName;
  final String? operationalCity;
  // business verification (employer + agency)
  final String? tinNumber;
  final String? subscriptionTier;

  Map<String, dynamic> toJson() {
    final base = <String, dynamic>{
      'role': role.name,
      'phone': phone,
      'password': password,
      if (email != null && email!.isNotEmpty) 'email': email,
    };

    switch (role) {
      case RegisterableRole.seeker:
        return {...base, 'full_name': fullName};
      case RegisterableRole.employer:
        return {
          ...base,
          'company_name': companyName,
          'tin_number': tinNumber,
          'subscription_tier': subscriptionTier,
          if (backofficePhone != null && backofficePhone!.isNotEmpty)
            'backoffice_phone': backofficePhone,
          if (promoDetails != null && promoDetails!.isNotEmpty)
            'promo_details': promoDetails,
        };
      case RegisterableRole.agency:
        return {
          ...base,
          'agency_name': agencyName,
          'tin_number': tinNumber,
          'subscription_tier': subscriptionTier,
          if (operationalCity != null && operationalCity!.isNotEmpty)
            'operational_city': operationalCity,
        };
    }
  }
}
