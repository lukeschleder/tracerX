import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log_record.dart';
import 'log_sink.dart';
import 'pii_masker.dart';
import 'tracer_trace.dart';

/// Asynchronously persists a finished [TracerTrace] to a `.tracer.json` file.
///
/// [write] is a lightweight counter so sinks stay uniform across the
/// [LogSink] interface; the authoritative event list always comes from
/// [TracerSession.export] / [persist]. Disk I/O is chained so rapid
/// `persist` calls never interleave writes.
class FileSink implements LogSink {
  FileSink({
    required this.directory,
    this.fileName,
  });

  /// Directory where `.tracer.json` files are written.
  final String directory;

  /// Optional override for the output filename (defaults to `<session>.tracer.json`).
  final String? fileName;

  Future<void> _writeChain = Future.value();
  int _writeCount = 0;
  int _persistCount = 0;

  /// Number of [write] calls observed during the session.
  int get writeCount => _writeCount;

  /// Number of successful [persist] completions.
  int get persistCount => _persistCount;

  @override
  void write(LogRecord record) {
    _writeCount++;
  }

  /// Masks PII and writes [trace] without blocking the caller’s event loop.
  Future<void> persist(TracerTrace trace) {
    final completer = Completer<void>();
    _writeChain = _writeChain.then((_) async {
      try {
        await _writeTrace(trace);
        _persistCount++;
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _writeTrace(TracerTrace trace) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final maskedTrace = _maskTrace(trace);
    final name = fileName ?? '${trace.sessionName}.tracer.json';
    final path = '${dir.path}${Platform.pathSeparator}$name';
    final json =
        const JsonEncoder.withIndent('  ').convert(maskedTrace.toJson());

    await File(path).writeAsString(json);
  }

  TracerTrace _maskTrace(TracerTrace trace) {
    final maskedEvents = trace.events.map((event) {
      return event.copyWith(
        metadata: PiiMasker.maskMetadata(event.metadata),
        message: PiiMasker.mask(event.message) as String,
        errorMessage: event.errorMessage != null
            ? PiiMasker.mask(event.errorMessage!) as String
            : null,
      );
    }).toList();

    return TracerTrace(
      sessionName: trace.sessionName,
      startedAt: trace.startedAt,
      endedAt: trace.endedAt,
      systemInfo: trace.systemInfo,
      events: maskedEvents,
    );
  }

  /// Waits for all pending async writes to finish.
  Future<void> flush() => _writeChain;
}
