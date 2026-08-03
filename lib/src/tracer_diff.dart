import 'dart:io';

import 'ansi_colors.dart';
import 'console_sink.dart';
import 'trace_event.dart';
import 'tracer_trace.dart';

/// Classification of a difference between two trace sessions.
enum DiffType {
  /// Present in the baseline but missing from the target.
  removed,

  /// Present in the target but missing from the baseline.
  added,

  /// Same call signature, but metadata/state payload changed.
  modified,
}

/// A single line-item in a [TracerDiff] comparison.
class DiffEntry {
  const DiffEntry({
    required this.type,
    required this.description,
    this.baselineEvent,
    this.targetEvent,
    this.baselineIndex,
    this.targetIndex,
  });

  final DiffType type;
  final TraceEvent? baselineEvent;
  final TraceEvent? targetEvent;
  final String description;
  final int? baselineIndex;
  final int? targetIndex;
}

/// Compares two exported [TracerTrace]s and builds a human-readable Fix Receipt.
///
/// Alignment uses longest-common-subsequence (LCS) over each event's
/// [TraceEvent.sequenceSignature] (qualified name + level + message).
/// Matched events are then compared for metadata payload changes.
///
/// This is intentionally **not** zone-based instrumentation: callers record
/// explicit checkpoints, which keeps traces deterministic and interviewable.
class TracerDiff {
  TracerDiff({
    required this.baseline,
    required this.target,
  });

  /// Loads both traces from `.tracer.json` files on disk.
  factory TracerDiff.fromFiles({
    required String baselinePath,
    required String targetPath,
  }) =>
      TracerDiff(
        baseline: TracerTrace.fromFile(baselinePath),
        target: TracerTrace.fromFile(targetPath),
      );

  /// The "before" / buggy execution trace.
  final TracerTrace baseline;

  /// The "after" / fixed execution trace.
  final TracerTrace target;

  /// Computed differences (lazy, memoized).
  late final List<DiffEntry> entries = _computeDiff();

  List<DiffEntry> _computeDiff() {
    final baseEvents = baseline.events;
    final targetEvents = target.events;
    final aligned = _alignEvents(baseEvents, targetEvents);

    final results = <DiffEntry>[];
    var prevBase = 0;
    var prevTarget = 0;

    for (final pair in aligned) {
      for (var i = prevBase; i < pair.baseIndex; i++) {
        results.add(
          DiffEntry(
            type: DiffType.removed,
            baselineEvent: baseEvents[i],
            baselineIndex: i,
            description:
                '[-] Baseline: ${_eventLabel(baseEvents[i])} at step ${i + 1}',
          ),
        );
      }

      for (var j = prevTarget; j < pair.targetIndex; j++) {
        results.add(
          DiffEntry(
            type: DiffType.added,
            targetEvent: targetEvents[j],
            targetIndex: j,
            description:
                '[+] Fixed: ${_eventLabel(targetEvents[j])} at step ${j + 1}',
          ),
        );
      }

      if (!_metadataEqual(
        baseEvents[pair.baseIndex].metadata,
        targetEvents[pair.targetIndex].metadata,
      )) {
        results.add(
          DiffEntry(
            type: DiffType.modified,
            baselineEvent: baseEvents[pair.baseIndex],
            targetEvent: targetEvents[pair.targetIndex],
            baselineIndex: pair.baseIndex,
            targetIndex: pair.targetIndex,
            description: _modifiedDescription(
              baseEvents[pair.baseIndex],
              targetEvents[pair.targetIndex],
            ),
          ),
        );
      }

      prevBase = pair.baseIndex + 1;
      prevTarget = pair.targetIndex + 1;
    }

    for (var i = prevBase; i < baseEvents.length; i++) {
      results.add(
        DiffEntry(
          type: DiffType.removed,
          baselineEvent: baseEvents[i],
          baselineIndex: i,
          description:
              '[-] Baseline: ${_eventLabel(baseEvents[i])} at step ${i + 1}',
        ),
      );
    }

    for (var j = prevTarget; j < targetEvents.length; j++) {
      results.add(
        DiffEntry(
          type: DiffType.added,
          targetEvent: targetEvents[j],
          targetIndex: j,
          description:
              '[+] Fixed: ${_eventLabel(targetEvents[j])} at step ${j + 1}',
        ),
      );
    }

    return results;
  }

  /// Classic DP LCS returning index pairs into [baseEvents] / [targetEvents].
  List<({int baseIndex, int targetIndex})> _alignEvents(
    List<TraceEvent> baseEvents,
    List<TraceEvent> targetEvents,
  ) {
    final m = baseEvents.length;
    final n = targetEvents.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (baseEvents[i - 1].sequenceSignature ==
            targetEvents[j - 1].sequenceSignature) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final pairs = <({int baseIndex, int targetIndex})>[];
    var i = m;
    var j = n;
    while (i > 0 && j > 0) {
      if (baseEvents[i - 1].sequenceSignature ==
          targetEvents[j - 1].sequenceSignature) {
        pairs.insert(0, (baseIndex: i - 1, targetIndex: j - 1));
        i--;
        j--;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    return pairs;
  }

  bool _metadataEqual(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key].toString() != b[key].toString()) {
        return false;
      }
    }
    return true;
  }

  String _eventLabel(TraceEvent event) {
    final location = event.location.isNotEmpty ? ' (${event.location})' : '';
    return '${event.qualifiedName}$location — ${event.message}';
  }

  String _modifiedDescription(TraceEvent base, TraceEvent target) {
    final changes = <String>[];
    final allKeys = {
      ...?base.metadata?.keys,
      ...?target.metadata?.keys,
    };

    for (final key in allKeys.toList()..sort()) {
      final baseVal = base.metadata?[key]?.toString() ?? '<missing>';
      final targetVal = target.metadata?[key]?.toString() ?? '<missing>';
      if (baseVal != targetVal) {
        changes.add('    $key: $baseVal → $targetVal');
      }
    }

    final header = '[!] Altered: ${_eventLabel(base)}';
    if (changes.isEmpty) return header;
    return '$header\n${changes.join('\n')}';
  }

  /// Human-readable Fix Receipt.
  ///
  /// When [colorize] is `null`, color is enabled if [ConsoleSink.detectsColorSupport]
  /// is true. Saved files should use `colorize: false`.
  String generateReceipt({bool? colorize}) {
    final useColor = colorize ?? ConsoleSink.detectsColorSupport;
    return _buildReceipt(useColor);
  }

  String _buildReceipt(bool colorize) {
    final buffer = StringBuffer()
      ..writeln(
        AnsiColors.wrap(
          '=== TracerX Fix Receipt ===',
          AnsiColors.bold + AnsiColors.cyan,
          enabled: colorize,
        ),
      )
      ..writeln(
        '${AnsiColors.wrap('Baseline:', AnsiColors.dim, enabled: colorize)} '
        '${baseline.sessionName}',
      )
      ..writeln(
        '${AnsiColors.wrap('Target:  ', AnsiColors.dim, enabled: colorize)} '
        '${target.sessionName}',
      )
      ..writeln(
        '${AnsiColors.wrap('Events:  ', AnsiColors.dim, enabled: colorize)} '
        '${baseline.events.length} → ${target.events.length}',
      )
      ..writeln();

    if (entries.isEmpty) {
      buffer.writeln(
        AnsiColors.wrap(
          'No differences detected. Traces are identical.',
          AnsiColors.green,
          enabled: colorize,
        ),
      );
      return buffer.toString();
    }

    for (final entry in entries) {
      buffer.writeln(_colorizeEntry(entry.description, entry.type, colorize));
      buffer.writeln();
    }

    final added = entries.where((e) => e.type == DiffType.added).length;
    final removed = entries.where((e) => e.type == DiffType.removed).length;
    final modified = entries.where((e) => e.type == DiffType.modified).length;

    buffer
      ..writeln(
        AnsiColors.wrap(
          '--- Summary ---',
          AnsiColors.bold,
          enabled: colorize,
        ),
      )
      ..writeln(
        '${AnsiColors.wrap('Added:   ', AnsiColors.green, enabled: colorize)}'
        '$added',
      )
      ..writeln(
        '${AnsiColors.wrap('Removed: ', AnsiColors.red, enabled: colorize)}'
        '$removed',
      )
      ..writeln(
        '${AnsiColors.wrap('Modified:', AnsiColors.yellow, enabled: colorize)} '
        '$modified',
      );

    return buffer.toString();
  }

  String _colorizeEntry(String description, DiffType type, bool colorize) {
    final code = switch (type) {
      DiffType.removed => AnsiColors.red,
      DiffType.added => AnsiColors.green,
      DiffType.modified => AnsiColors.yellow,
    };

    final lines = description.split('\n');
    return lines
        .map((line) => AnsiColors.wrap(line, code, enabled: colorize))
        .join('\n');
  }

  /// Writes a plain-text (no ANSI) Fix Receipt to [outputPath].
  Future<void> saveReceipt(String outputPath) async {
    await File(outputPath).writeAsString(generateReceipt(colorize: false));
  }
}
