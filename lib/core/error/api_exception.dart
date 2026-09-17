/// A single field-level validation error, as returned in the backend's
/// `errors` array: `{ field?, message }`.
class ApiFieldError {
  const ApiFieldError({required this.message, this.field});

  final String? field;
  final String message;

  factory ApiFieldError.fromJson(Map<String, dynamic> json) => ApiFieldError(
        field: json['field'] as String?,
        message: (json['message'] as String?) ?? 'Invalid value',
      );
}

/// Normalized error type thrown by [ApiClient] for every failed request.
///
/// Mirrors the backend's error envelope:
/// `{ status: "error" | "fail", message, errors? }`
/// so call sites never have to touch raw Dio/HTTP details — they can just
/// do `catch (e) { if (e is ApiException) show(e.message); }`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  final String message;
  final int? statusCode;
  final List<ApiFieldError>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidationError => errors != null && errors!.isNotEmpty;

  @override
  String toString() => message;
}
