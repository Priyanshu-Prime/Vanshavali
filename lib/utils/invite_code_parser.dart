/// Pure-Dart parsing for invite codes coming from a scanned QR payload or
/// pasted text.
///
/// The QR system is "option a": a bare 6-character code is encoded. But we
/// stay forgiving on the read side so a code embedded in a future deep link
/// (e.g. `vanshavali://auth?code=ABC123`) still resolves — we pull the `code`
/// query param when the payload looks like a URL, otherwise we treat the whole
/// payload as the candidate code.
///
/// A valid invite code is exactly 6 characters of A–Z / 0–9 (the format
/// produced by the `generate_invite_code` RPC). Returns the normalized
/// (trimmed + uppercased) code, or `null` if no plausible code is present.
library;

/// Matches exactly six uppercase-alphanumeric characters.
final RegExp _sixCharCode = RegExp(r'^[A-Z0-9]{6}$');

/// Extracts a valid 6-character invite code from an arbitrary scanned/pasted
/// [raw] payload, or returns `null` when none is found.
String? parseInviteCode(String? raw) {
  if (raw == null) return null;

  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // If the payload is a URL that carries a `code` query parameter, prefer that.
  final fromUrl = _codeFromUrl(trimmed);
  if (fromUrl != null) {
    return _normalizeCandidate(fromUrl);
  }

  // Otherwise treat the whole payload as the candidate code.
  return _normalizeCandidate(trimmed);
}

/// Returns the raw `code` query-parameter value if [text] parses as a URI that
/// has one, else `null`. Does not validate the code shape — that is left to
/// [_normalizeCandidate].
String? _codeFromUrl(String text) {
  // Cheap guard: only bother with URI parsing when it plausibly looks like one.
  if (!text.contains('://') && !text.contains('?')) return null;

  final uri = Uri.tryParse(text);
  if (uri == null) return null;

  final code = uri.queryParameters['code'];
  if (code == null || code.trim().isEmpty) return null;
  return code;
}

/// Normalizes [candidate] (trim + uppercase) and returns it only if it is a
/// valid 6-character invite code, else `null`.
String? _normalizeCandidate(String candidate) {
  final normalized = candidate.trim().toUpperCase();
  if (_sixCharCode.hasMatch(normalized)) return normalized;
  return null;
}
