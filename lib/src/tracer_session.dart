import 'log_level.dart';
import 'log_record.dart';
import 'log_sink.dart';
import 'console_sink.dart';
import 'file_sink.dart';
import 'stack_trace_parser.dart';
import 'system_info.dart';
import 'trace_event.dart';
import 'tracer_trace.dart';

/// Records an ordered execution trace for golden-master / bug-fix comparison.
///
/// Prefer creating sessions via [TracerX.startSession]. Each `info` / `debug` /
/// `error` call captures:
/// - wall-clock timestamp
/// - severity
/// - optional [tag] (defaults to the session [name])
/// - caller class, method, file, and line (via [StackTraceParser])
/// - optional JSON-serializable [metadata] (your "state snapshot")
///
/// Call [end] when the flow finishes to flush [FileSink]s and obtain a
/// [TracerTrace] suitable for [TracerDiff].
class TracerSession {
  /// Creates a named recording session.
  ///
  /// When [sinks] is omitted, a [ConsoleSink] is used so traces are visible
  /// during interactive debugging.
  TracerSession(
    this.name, {
    List<LogSink>? sinks,
    this.minLevel = LogLevel.debug,
  })  : startedAt = DateTime.now(),
        systemInfo = SystemInfo.current(),
        sinks = List.unmodifiable(sinks ?? [ConsoleSink()]);

  /// Human-readable session label (also used as default file name / tag).
  final String name;

  /// Wall-clock start time.
  final DateTime startedAt;

  /// Host / runtime snapshot captured at construction.
  final SystemInfo systemInfo;

  /// Fan-out destinations for each recorded event.
  final List<LogSink> sinks;

  /// Events below this level are discarded.
  final LogLevel minLevel;

  final List<TraceEvent> _events = [];
  DateTime? _endedAt;
  bool _closed = false;

  /// Immutable view of events recorded so far.
  List<TraceEvent> get events => List.unmodifiable(_events);

  /// Whether [end] has already been called.
  bool get isClosed => _closed;

  /// Records a debug-level checkpoint.
  void debug(
    String message, {
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.debug, message, metadata: metadata, tag: tag);

  /// Records an info-level checkpoint.
  void info(
    String message, {
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.info, message, metadata: metadata, tag: tag);

  /// Records an error-level checkpoint, optionally with an [error] object.
  void error(
    String message, {
    Map<String, dynamic>? metadata,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(
        LogLevel.error,
        message,
        metadata: metadata,
        tag: tag,
        error: error,
        stackTrace: stackTrace ?? (error != null ? StackTrace.current : null),
      );

  void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? metadata,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_closed) {
      throw StateError('Session "$name" is already closed.');
    }
    if (level.index < minLevel.index) return;

    final caller = StackTraceParser.parseCaller(StackTrace.current);
    final eventTag = tag ?? name;

    final event = TraceEvent(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: eventTag,
      className: caller?.className,
      methodName: caller?.methodName,
      file: caller?.file,
      line: caller?.line,
      metadata: metadata == null ? null : Map<String, dynamic>.from(metadata),
      errorMessage: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    _events.add(event);

    final record = LogRecord.fromTraceEvent(event);
    for (final sink in sinks) {
      sink.write(record);
    }
  }

  /// Snapshot of the session as a structured [TracerTrace].
  TracerTrace export() => TracerTrace(
        sessionName: name,
        startedAt: startedAt,
        endedAt: _endedAt,
        systemInfo: systemInfo,
        events: List.unmodifiable(_events),
      );

  /// Closes the session, persists any [FileSink]s, and returns the final trace.
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
