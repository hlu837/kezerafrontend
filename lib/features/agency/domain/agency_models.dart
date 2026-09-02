/// A picked file's bytes + filename, decoupled from `file_picker`'s own
/// `PlatformFile` type so the repository/data layer doesn't need to know
/// about the picker package. Bytes (not a path) work on every platform
/// `file_picker` supports, including web, where there is no filesystem
/// path to read from.
class WalkInAttachment {
  const WalkInAttachment({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

/// POST /agencies/walk-in — sent as multipart/form-data since it can carry
/// optional cv/photo attachments (see `agency.routes.js`). Every non-file
/// field arrives on the backend as a plain string, hence `skills` being a
/// comma-joined string here rather than a list — mirrors
/// `types/agency.ts`'s `WalkInPayload` / `walkInSchema`'s custom parser.
class WalkInPayload {
  const WalkInPayload({
    required this.fullName,
    required this.phone,
    this.email,
    this.city,
    this.bio,
    this.skills = const [],
  });

  final String fullName;
  final String phone;
  final String? email;
  final String? city;
  final String? bio;
  final List<String> skills;

  Map<String, String> toFields() => {
        'full_name': fullName,
        'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email!,
        if (city != null && city!.isNotEmpty) 'city': city!,
        if (bio != null && bio!.isNotEmpty) 'bio': bio!,
        if (skills.isNotEmpty) 'skills': skills.join(','),
      };
}

/// Just the bit of the response the walk-in screen actually needs — the
/// full envelope also returns the created `user`, but the success message
/// only shows the registered candidate's name.
class WalkInResult {
  const WalkInResult({required this.fullName});

  final String fullName;

  factory WalkInResult.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>;
    return WalkInResult(fullName: profile['fullName'] as String? ?? '');
  }
}

/// POST /agencies/dispatch — sends a shortlist of matched candidates to
/// the job's poster. Mirrors `types/agency.ts`'s `DispatchPayload`.
class DispatchPayload {
  const DispatchPayload({required this.jobId, required this.seekerIds});

  final String jobId;
  final List<String> seekerIds;

  Map<String, dynamic> toJson() => {
        'job_id': jobId,
        'seeker_ids': seekerIds,
      };
}
