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
///
/// Optionally prepend [prefix] to every line, and skip records whose tag is
/// outside [filterTag] / [filterTags].
class ConsoleSink implements LogSink {
  ConsoleSink({
    bool? colorize,
    this.prefix,
    String? filterTag,
    List<String>? filterTags,
    IOSink? out,
    IOSink? err,
  })  : colorize = colorize ?? detectsColorSupport,
        allowedTags = resolveTagFilters(
          filterTag: filterTag,
          filterTags: filterTags,
        ),
        _out = out,
        _err = err;

  /// Whether ANSI styling is applied to emitted lines.
  final bool colorize;

  /// Optional string prepended to every console line (for example `tracer: `).
  final String? prefix;

  /// Effective tag allow-list, or `null` when every tag is accepted.
  final Set<String>? allowedTags;

  final IOSink? _out;
  final IOSink? _err;

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
    if (!tagMatchesFilter(record.tag, allowedTags)) return;

    final line = formatLine(record);
    final output =
        record.level == LogLevel.error ? (_err ?? stderr) : (_out ?? stdout);
    output.writeln(line);

    if (record.error != null) {
      output.writeln(
        _withPrefix(
          AnsiColors.wrap(
            PiiMasker.mask(record.error.toString()) as String,
            AnsiColors.red,
            enabled: colorize,
          ),
        ),
      );
    }
    if (record.stackTrace != null) {
      output.writeln(
        _withPrefix(
          AnsiColors.wrap(
            record.stackTrace.toString(),
            AnsiColors.dim,
            enabled: colorize,
          ),
        ),
      );
    }
  }

  /// Formats a single log line (including optional [prefix]).
  ///
  /// Exposed for unit tests and custom rendering without writing to a terminal.
  String formatLine(LogRecord record) {
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

    return _withPrefix('${parts.join(' ')} │ $body$metaSuffix');
  }

  String _withPrefix(String line) {
    if (prefix == null || prefix!.isEmpty) return line;
    return '$prefix$line';
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
