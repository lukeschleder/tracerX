import 'log_level.dart';
import 'trace_event.dart';

/// A single log event emitted by [Tracer] or [TracerSession].
class LogRecord {
  const LogRecord({
    required this.level,
    required this.message,
    required this.timestamp,
    this.tag,
    this.className,
    this.methodName,
    this.file,
    this.line,
    this.metadata,
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? tag;
  final String? className;
  final String? methodName;
  final String? file;
  final int? line;
  final Map<String, dynamic>? metadata;
  final Object? error;
  final StackTrace? stackTrace;

  String get location {
    if (file == null || line == null) return '';
    return '$file:$line';
  }

  String get qualifiedName {
    if (className != null && methodName != null) {
      return '$className.$methodName';
    }
    return methodName ?? className ?? '';
  }

  factory LogRecord.fromTraceEvent(TraceEvent event, {String? tag}) =>
      LogRecord(
        level: event.level,
        message: event.message,
        timestamp: event.timestamp,
        tag: tag,
        className: event.className,
        methodName: event.methodName,
        file: event.file,
        line: event.line,
        metadata: event.metadata,
        error: event.errorMessage,
        stackTrace: event.stackTrace != null
            ? StackTrace.fromString(event.stackTrace!)
            : null,
      );
}
