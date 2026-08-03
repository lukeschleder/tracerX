import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log_record.dart';
import 'log_sink.dart';
import 'pii_masker.dart';
import 'tracer_trace.dart';

/// Asynchronously persists trace sessions to `.tracer.json` files on disk.
class FileSink implements LogSink {
  FileSink({
    required this.directory,
    this.fileName,
  });

  final String directory;
  final String? fileName;

  final List<LogRecord> _buffer = [];
  Future<void> _writeChain = Future.value();
  int _persistCount = 0;

  /// Number of times [persist] has completed successfully.
  int get persistCount => _persistCount;

  /// Buffered records awaiting persistence.
  int get bufferedCount => _buffer.length;

  @override
  void write(LogRecord record) {
    _buffer.add(record);
  }

  /// Serializes and writes the session trace without blocking the caller.
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
    final path = '${dir.path}/$name';
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

  /// Clears buffered records (testing helper).
  void clearBuffer() => _buffer.clear();
}
