import 'log_level.dart';
import 'log_record.dart';
import 'log_sink.dart';
import 'console_sink.dart';
import 'file_sink.dart';
import 'stack_trace_parser.dart';
import 'system_info.dart';
import 'trace_event.dart';
import 'tracer_trace.dart';

/// Records an ordered execution trace with exportable JSON output.
class TracerSession {
  TracerSession(
    this.name, {
    List<LogSink>? sinks,
    this.minLevel = LogLevel.debug,
  })  : startedAt = DateTime.now(),
        systemInfo = SystemInfo.current(),
        sinks = sinks ?? [ConsoleSink()];

  final String name;
  final DateTime startedAt;
  final SystemInfo systemInfo;
  final List<LogSink> sinks;
  final LogLevel minLevel;

  final List<TraceEvent> _events = [];
  DateTime? _endedAt;
  bool _closed = false;

  List<TraceEvent> get events => List.unmodifiable(_events);

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
    if (_closed) {
      throw StateError('Session "$name" is already closed.');
    }
    if (level.index < minLevel.index) return;

    final caller = StackTraceParser.parseCaller(StackTrace.current);

    final event = TraceEvent(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      className: caller?.className,
      methodName: caller?.methodName,
      file: caller?.file,
      line: caller?.line,
      metadata: metadata,
      errorMessage: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    _events.add(event);

    final record = LogRecord.fromTraceEvent(event, tag: name);
    for (final sink in sinks) {
      sink.write(record);
    }
  }

  /// Exports the current session as a structured [TracerTrace].
  TracerTrace export() => TracerTrace(
        sessionName: name,
        startedAt: startedAt,
        endedAt: _endedAt,
        systemInfo: systemInfo,
        events: List.unmodifiable(_events),
      );

  /// Closes the session, flushes file sinks, and returns the final trace.
  Future<TracerTrace> end() async {
    if (_closed) return export();
    _endedAt = DateTime.now();
    _closed = true;

    final trace = export();
    await Future.wait(
      sinks.whereType<FileSink>().map((sink) => sink.persist(trace)),
    );
    return trace;
  }
}
