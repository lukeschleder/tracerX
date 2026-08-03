import 'log_level.dart';
import 'log_record.dart';
import 'log_sink.dart';
import 'console_sink.dart';
import 'stack_trace_parser.dart';

/// Fire-and-forget logger with automatic caller location and pluggable sinks.
///
/// Prefer [TracerSession] when you need exportable traces for [TracerDiff].
/// Use [Tracer] for day-to-day diagnostic logging.
class Tracer {
  /// Creates a logger that writes to [sink] (defaults to [ConsoleSink]).
  Tracer({
    LogSink? sink,
    this.tag,
    this.minLevel = LogLevel.debug,
  }) : sink = sink ?? ConsoleSink();

  /// Destination for each log record.
  final LogSink sink;

  /// Optional tag rendered as `[tag]` in console output.
  final String? tag;

  /// Events below this level are discarded.
  final LogLevel minLevel;

  /// Logs a debug message.
  void debug(String message, {Map<String, dynamic>? metadata}) =>
      _log(LogLevel.debug, message, metadata: metadata);

  /// Logs an info message.
  void info(String message, {Map<String, dynamic>? metadata}) =>
      _log(LogLevel.info, message, metadata: metadata);

  /// Logs an error message, optionally attaching [error] / [stackTrace].
  void error(
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(
        LogLevel.error,
        message,
        metadata: metadata,
        error: error,
        stackTrace: stackTrace ?? (error != null ? StackTrace.current : null),
      );

  void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final caller = StackTraceParser.parseCaller(StackTrace.current);

    sink.write(
      LogRecord(
        level: level,
        message: message,
        timestamp: DateTime.now(),
        tag: tag,
        className: caller?.className,
        methodName: caller?.methodName,
        file: caller?.file,
        line: caller?.line,
        metadata: metadata,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
