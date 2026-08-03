import 'log_level.dart';
import 'log_record.dart';
import 'log_sink.dart';
import 'console_sink.dart';
import 'stack_trace_parser.dart';

/// Lightweight logger with automatic caller location and pluggable output.
class Tracer {
  Tracer({
    LogSink? sink,
    this.tag,
    this.minLevel = LogLevel.debug,
  }) : sink = sink ?? ConsoleSink();

  final LogSink sink;
  final String? tag;
  final LogLevel minLevel;

  void debug(String message, {Map<String, dynamic>? metadata}) =>
      _log(LogLevel.debug, message, metadata: metadata);

  void info(String message, {Map<String, dynamic>? metadata}) =>
      _log(LogLevel.info, message, metadata: metadata);

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
