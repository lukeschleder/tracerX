/// Severity levels supported by [Tracer] and [TracerSession].
enum LogLevel {
  /// Verbose diagnostic detail.
  debug,

  /// Routine operational checkpoint.
  info,

  /// Failure or unexpected condition.
  error;

  /// Serializes to a stable lowercase name.
  String toJson() => name;

  /// Parses a level from its [name].
  static LogLevel fromJson(String value) => LogLevel.values.byName(value);
}
