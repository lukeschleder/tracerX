import 'log_sink.dart';
import 'tracer_session.dart';

/// Facade for creating and tracking recorded [TracerSession]s.
///
/// ```dart
/// final session = TracerX.startSession('checkout');
/// session.info('Cart validated', metadata: {'items': 3});
/// final trace = await session.end();
/// ```
class TracerX {
  TracerX._();

  static TracerSession? _activeSession;

  /// Creates a new recorded session and marks it as [activeSession].
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

  /// Clears [activeSession] without calling [TracerSession.end].
  static void clearActiveSession() => _activeSession = null;
}
