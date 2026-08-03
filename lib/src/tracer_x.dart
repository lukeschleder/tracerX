import 'log_sink.dart';
import 'tracer_session.dart';

/// Entry point for creating and managing recorded trace sessions.
class TracerX {
  TracerX._();

  static TracerSession? _activeSession;

  /// Creates a new recorded trace session and sets it as the active session.
  static TracerSession startSession(
    String name, {
    List<LogSink>? sinks,
  }) {
    final session = TracerSession(name, sinks: sinks);
    _activeSession = session;
    return session;
  }

  /// The most recently started session, if any.
  static TracerSession? get activeSession => _activeSession;

  /// Clears the active session reference without closing it.
  static void clearActiveSession() => _activeSession = null;
}
