import 'dart:io';

import 'trace_event.dart';
import 'tracer_trace.dart';

/// Classification of a difference between two trace sessions.
enum DiffType {
  removed,
  added,
  modified,
  reordered,
}

/// A single line in a trace comparison report.
class DiffEntry {
  const DiffEntry({
    required this.type,
    this.baselineEvent,
    this.targetEvent,
    required this.description,
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

/// Compares two exported traces and generates a human-readable Fix Receipt.
class TracerDiff {
  TracerDiff({
    required this.baseline,
    required this.target,
  });

  factory TracerDiff.fromFiles({
    required String baselinePath,
    required String targetPath,
  }) =>
      TracerDiff(
        baseline: TracerTrace.fromFile(baselinePath),
        target: TracerTrace.fromFile(targetPath),
      );

  final TracerTrace baseline;
  final TracerTrace target;

  late final List<DiffEntry> entries = _computeDiff();
  late final String receipt = _buildReceipt();

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
        final reorderedFrom =
            _findIndexBySignature(baseEvents, targetEvents[j]);
        if (reorderedFrom != null &&
            reorderedFrom >= prevBase &&
            reorderedFrom != j) {
          results.add(
            DiffEntry(
              type: DiffType.reordered,
              baselineEvent: baseEvents[reorderedFrom],
              targetEvent: targetEvents[j],
              baselineIndex: reorderedFrom,
              targetIndex: j,
              description: '[~] Reordered: ${_eventLabel(targetEvents[j])} '
                  'step ${reorderedFrom + 1} → ${j + 1}',
            ),
          );
        } else {
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

  int? _findIndexBySignature(List<TraceEvent> events, TraceEvent target) {
    for (var i = 0; i < events.length; i++) {
      if (events[i].sequenceSignature == target.sequenceSignature) return i;
    }
    return null;
  }

  bool _metadataEqual(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null && b == null) return true;
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

    for (final key in allKeys) {
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

  String _buildReceipt() {
    final buffer = StringBuffer()
      ..writeln('=== TracerX Fix Receipt ===')
      ..writeln('Baseline: ${baseline.sessionName}')
      ..writeln('Target:   ${target.sessionName}')
      ..writeln(
        'Events:   ${baseline.events.length} → ${target.events.length}',
      )
      ..writeln();

    if (entries.isEmpty) {
      buffer.writeln('No differences detected. Traces are identical.');
      return buffer.toString();
    }

    for (final entry in entries) {
      buffer.writeln(entry.description);
      buffer.writeln();
    }

    final added = entries.where((e) => e.type == DiffType.added).length;
    final removed = entries.where((e) => e.type == DiffType.removed).length;
    final modified = entries.where((e) => e.type == DiffType.modified).length;
    final reordered = entries.where((e) => e.type == DiffType.reordered).length;

    buffer
      ..writeln('--- Summary ---')
      ..writeln('Added:     $added')
      ..writeln('Removed:   $removed')
      ..writeln('Modified:  $modified')
      ..writeln('Reordered: $reordered');

    return buffer.toString();
  }

  /// Returns the human-readable Fix Receipt summary.
  String generateReceipt() => receipt;

  /// Writes the Fix Receipt report to [outputPath].
  Future<void> saveReceipt(String outputPath) async {
    await File(outputPath).writeAsString(receipt);
  }
}
