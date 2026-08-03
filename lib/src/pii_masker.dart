/// Redacts sensitive keys and patterns from log payloads before output.
///
/// Applied by [ConsoleSink] and [FileSink] so PII never reaches terminals
/// or persisted `.tracer.json` files by default.
class PiiMasker {
  PiiMasker._();

  static const redacted = '***REDACTED***';

  /// Exact key names (case-insensitive) that are always redacted.
  static const sensitiveKeys = {
    'token',
    'password',
    'passwd',
    'secret',
    'api_key',
    'apikey',
    'api-key',
    'auth',
    'authorization',
    'credential',
    'credentials',
    'ssn',
    'email',
    'access_token',
    'refresh_token',
  };

  static final _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static final _bearerPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );

  /// Returns a deep copy of [value] with sensitive data masked.
  static dynamic mask(dynamic value) {
    if (value is Map) {
      return value.map((key, val) {
        final keyStr = key.toString().toLowerCase();
        if (sensitiveKeys.contains(keyStr)) {
          return MapEntry(key, redacted);
        }
        return MapEntry(key, mask(val));
      });
    }

    if (value is List) {
      return value.map(mask).toList();
    }

    if (value is String) {
      return _maskString(value);
    }

    return value;
  }

  static String _maskString(String value) {
    var result = value.replaceAll(_emailPattern, redacted);
    result = result.replaceAll(_bearerPattern, 'Bearer $redacted');
    return result;
  }

  /// Masks a metadata map, or returns `null` when [metadata] is null.
  static Map<String, dynamic>? maskMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    return Map<String, dynamic>.from(mask(metadata) as Map);
  }
}
