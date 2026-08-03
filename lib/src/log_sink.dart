import 'log_record.dart';

/// Receives formatted log output from [Tracer] or [TracerSession].
///
/// Implement this to route events to files, network collectors, test spies, etc.
abstract class LogSink {
  /// Handles a single [LogRecord]. Must not throw for normal operation.
  void write(LogRecord record);
}

/// Builds the effective allow-list from optional single and multi tag filters.
///
/// Returns `null` when no filter is configured (all tags pass).
Set<String>? resolveTagFilters({
  String? filterTag,
  List<String>? filterTags,
}) {
  final allowed = <String>{
    if (filterTag != null) filterTag,
    ...?filterTags,
  };
  return allowed.isEmpty ? null : allowed;
}

/// Returns true when [tag] is allowed by [allowedTags].
///
/// A `null` [allowedTags] means no filtering (everything passes).
bool tagMatchesFilter(String? tag, Set<String>? allowedTags) {
  if (allowedTags == null) return true;
  return tag != null && allowedTags.contains(tag);
}
