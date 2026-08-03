import 'log_level.dart';

/// A single recorded checkpoint within a [TracerTrace] session.
///
/// [metadata] is the structured "state snapshot" compared by [TracerDiff]
/// when two events share the same [sequenceSignature].
class TraceEvent {
  /// Creates an immutable trace event.
  const TraceEvent({
    required this.timestamp,
    required this.level,
    required this.message,
    this.className,
    this.methodName,
    this.file,
    this.line,
    this.metadata,
    this.errorMessage,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? className;
  final String? methodName;
  final String? file;
  final int? line;

  /// Arbitrary JSON-serializable state captured at this checkpoint.
  final Map<String, dynamic>? metadata;
  final String? errorMessage;
  final String? stackTrace;

  /// `file:line` when both are present, otherwise empty.
  String get location {
    if (file == null || line == null) return '';
    return '$file:$line';
  }

  /// `Class.method`, falling back to method / class / `<unknown>`.
  String get qualifiedName {
    if (className != null && methodName != null) {
      return '$className.$methodName';
    }
    return methodName ?? className ?? '<unknown>';
  }

  /// Signature used for LCS sequence alignment.
  ///
  /// Uses level + message only so renamed methods in a fixed code path still
  /// align with the buggy baseline. Metadata is compared separately after match.
  String get sequenceSignature => '${level.name}|$message';

  /// Full signature including sorted metadata key/values.
  String get signature => '$sequenceSignature|${_metadataSignature()}';

  String _metadataSignature() {
    if (metadata == null || metadata!.isEmpty) return '';
    final keys = metadata!.keys.toList()..sort();
    return keys.map((k) => '$k=${metadata![k]}').join(',');
  }

  /// JSON representation suitable for `.tracer.json` export.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'level': level.toJson(),
        'message': message,
        if (className != null) 'className': className,
        if (methodName != null) 'methodName': methodName,
        if (file != null) 'file': file,
        if (line != null) 'line': line,
        if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };

  /// Returns a copy with selective field overrides.
  TraceEvent copyWith({
    Map<String, dynamic>? metadata,
    String? message,
    String? errorMessage,
  }) =>
      TraceEvent(
        timestamp: timestamp,
        level: level,
        message: message ?? this.message,
        className: className,
        methodName: methodName,
        file: file,
        line: line,
        metadata: metadata ?? this.metadata,
        errorMessage: errorMessage ?? this.errorMessage,
        stackTrace: stackTrace,
      );

  /// Restores an event from JSON produced by [toJson].
  factory TraceEvent.fromJson(Map<String, dynamic> json) => TraceEvent(
        timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
        level: LogLevel.fromJson(json['level'] as String),
        message: json['message'] as String,
        className: json['className'] as String?,
        methodName: json['methodName'] as String?,
        file: json['file'] as String?,
        line: json['line'] as int?,
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : null,
        errorMessage: json['errorMessage'] as String?,
        stackTrace: json['stackTrace'] as String?,
      );
}
