import 'dart:io';

import 'ansi_colors.dart';
import 'log_level.dart';
import 'log_record.dart';
import 'log_sink.dart';
import 'pii_masker.dart';

/// Writes colorized log lines to stdout (stderr for [LogLevel.error]).
///
/// Color is enabled automatically when writing to a TTY and `NO_COLOR` is
/// unset. Pass [colorize] to force on/off (useful in tests and CI).
class ConsoleSink implements LogSink {
  ConsoleSink({bool? colorize}) : colorize = colorize ?? detectsColorSupport;

  /// Whether ANSI styling is applied to emitted lines.
  final bool colorize;

  /// True when stdout is a terminal and `NO_COLOR` is not set.
  static bool get detectsColorSupport {
    if (Platform.environment.containsKey('NO_COLOR')) return false;
    try {
      return stdout.hasTerminal;
    } on StdoutException {
      return false;
    }
  }

  @override
  void write(LogRecord record) {
    final message = PiiMasker.mask(record.message) as String;
    final metadata = PiiMasker.maskMetadata(record.metadata);
    final levelStyle = _levelStyle(record.level);

    final parts = <String>[
      AnsiColors.wrap(
        _formatTimestamp(record.timestamp),
        AnsiColors.gray,
        enabled: colorize,
      ),
      AnsiColors.wrap(
        _levelLabel(record.level).padRight(5),
        levelStyle,
        enabled: colorize,
      ),
    ];

    if (record.tag != null) {
      parts.add(
        AnsiColors.wrap(
          '[${record.tag}]',
          AnsiColors.cyan,
          enabled: colorize,
        ),
      );
    }

    if (record.qualifiedName.isNotEmpty) {
      parts.add(
        AnsiColors.wrap(
          record.qualifiedName,
          AnsiColors.blue,
          enabled: colorize,
        ),
      );
    }

    if (record.location.isNotEmpty) {
      parts.add(
        AnsiColors.wrap(
          record.location,
          AnsiColors.dim,
          enabled: colorize,
        ),
      );
    }

    final body = AnsiColors.wrap(message, levelStyle, enabled: colorize);
    final metaSuffix =
        metadata != null && metadata.isNotEmpty ? ' $metadata' : '';

    final line = '${parts.join(' ')} │ $body$metaSuffix';
    final output = record.level == LogLevel.error ? stderr : stdout;
    output.writeln(line);

    if (record.error != null) {
      output.writeln(
        AnsiColors.wrap(
          PiiMasker.mask(record.error.toString()) as String,
          AnsiColors.red,
          enabled: colorize,
        ),
      );
    }
    if (record.stackTrace != null) {
      output.writeln(
        AnsiColors.wrap(
          record.stackTrace.toString(),
          AnsiColors.dim,
          enabled: colorize,
        ),
      );
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
        LogLevel.info => AnsiColors.green + AnsiColors.bold,
        LogLevel.error => AnsiColors.red + AnsiColors.bold,
      };
}

/// Backward-compatible alias for [ConsoleSink].
typedef ConsoleLogSink = ConsoleSink;
