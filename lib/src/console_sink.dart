import 'dart:io';

import 'ansi_colors.dart';
import 'log_level.dart';
import 'log_record.dart';
import 'log_sink.dart';
import 'pii_masker.dart';

/// Writes colorized log lines to stdout (or stderr for errors).
class ConsoleSink implements LogSink {
  ConsoleSink({bool? colorize}) : _colorize = colorize ?? _supportsColor;

  final bool _colorize;

  static bool get _supportsColor {
    if (!stdout.hasTerminal) return false;
    if (Platform.environment.containsKey('NO_COLOR')) return false;
    return true;
  }

  @override
  void write(LogRecord record) {
    final message = PiiMasker.mask(record.message) as String;
    final metadata = PiiMasker.maskMetadata(record.metadata);

    final buffer = StringBuffer();
    final levelStyle = _levelStyle(record.level);

    if (_colorize) {
      buffer
        ..write(AnsiColors.gray)
        ..write(_formatTimestamp(record.timestamp))
        ..write(AnsiColors.reset)
        ..write(' ')
        ..write(levelStyle)
        ..write(_levelLabel(record.level).padRight(5))
        ..write(AnsiColors.reset);
    } else {
      buffer
        ..write(_formatTimestamp(record.timestamp))
        ..write(' ')
        ..write(_levelLabel(record.level).padRight(5));
    }

    if (record.tag != null) {
      if (_colorize) {
        buffer
          ..write(' ')
          ..write(AnsiColors.cyan)
          ..write('[${record.tag}]')
          ..write(AnsiColors.reset);
      } else {
        buffer.write(' [${record.tag}]');
      }
    }

    if (record.qualifiedName.isNotEmpty) {
      if (_colorize) {
        buffer
          ..write(' ')
          ..write(AnsiColors.blue)
          ..write(record.qualifiedName)
          ..write(AnsiColors.reset);
      } else {
        buffer.write(' ${record.qualifiedName}');
      }
    }

    if (record.location.isNotEmpty) {
      if (_colorize) {
        buffer
          ..write(' ')
          ..write(AnsiColors.dim)
          ..write(record.location)
          ..write(AnsiColors.reset);
      } else {
        buffer.write(' ${record.location}');
      }
    }

    buffer.write(' │ ');

    if (_colorize) {
      buffer
        ..write(levelStyle)
        ..write(message)
        ..write(AnsiColors.reset);
    } else {
      buffer.write(message);
    }

    if (metadata != null && metadata.isNotEmpty) {
      buffer.write(' $metadata');
    }

    final output = record.level == LogLevel.error ? stderr : stdout;
    output.writeln(buffer.toString());

    if (record.error != null) {
      output.writeln(PiiMasker.mask(record.error.toString()));
    }
    if (record.stackTrace != null) {
      output.writeln(record.stackTrace);
    }
  }

  String _formatTimestamp(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String _levelLabel(LogLevel level) => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.error => 'ERROR',
      };

  String _levelStyle(LogLevel level) => switch (level) {
        LogLevel.debug => AnsiColors.gray,
        LogLevel.info => AnsiColors.green,
        LogLevel.error => AnsiColors.red + AnsiColors.bold,
      };
}

/// Backward-compatible alias for [ConsoleSink].
typedef ConsoleLogSink = ConsoleSink;
