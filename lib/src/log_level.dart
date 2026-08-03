/// Severity levels supported by [Tracer] and [TracerSession].
enum LogLevel {
  debug,
  info,
  error;

  String toJson() => name;

  static LogLevel fromJson(String value) => LogLevel.values.byName(value);
}
