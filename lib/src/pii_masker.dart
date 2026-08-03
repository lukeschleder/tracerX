/// Redacts sensitive keys and patterns from log payloads before output.
class PiiMasker {
  PiiMasker._();

  static const _redacted = '***REDACTED***';

  static final _sensitiveKeyPattern = RegExp(
    r'(token|password|passwd|secret|api[_-]?key|auth|credential|ssn|email)',
    caseSensitive: false,
  );

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
        final keyStr = key.toString();
        if (_sensitiveKeyPattern.hasMatch(keyStr)) {
          return MapEntry(key, _redacted);
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
    var result = value.replaceAll(_emailPattern, _redacted);
    result = result.replaceAll(_bearerPattern, 'Bearer $_redacted');
    return result;
  }

  static Map<String, dynamic>? maskMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    return Map<String, dynamic>.from(mask(metadata) as Map);
  }
}
