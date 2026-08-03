import 'log_record.dart';

/// Receives formatted log output from [Tracer].
abstract class LogSink {
  void write(LogRecord record);
}
