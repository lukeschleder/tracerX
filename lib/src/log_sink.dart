import 'log_record.dart';

/// Receives formatted log output from [Tracer] or [TracerSession].
///
/// Implement this to route events to files, network collectors, test spies, etc.
abstract class LogSink {
  /// Handles a single [LogRecord]. Must not throw for normal operation.
  void write(LogRecord record);
}
