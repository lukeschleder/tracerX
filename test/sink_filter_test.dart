import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tracer_x/tracer_x.dart';

void main() {
  group('ConsoleSink prefix', () {
    test('includes configured prefix on every formatted line', () {
      final sink = ConsoleSink(colorize: false, prefix: 'tracer: ');
      final line = sink.formatLine(
        LogRecord(
          level: LogLevel.info,
          message: 'hello',
          timestamp: DateTime(2026, 8, 3, 12, 0, 0),
          tag: 'demo',
        ),
      );

      expect(line, startsWith('tracer: '));
      expect(line, contains('INFO'));
      expect(line, contains('hello'));
    });

    test('omits prefix when null (backward compatible)', () {
      final sink = ConsoleSink(colorize: false);
      final line = sink.formatLine(
        LogRecord(
          level: LogLevel.info,
          message: 'hello',
          timestamp: DateTime(2026, 8, 3, 12, 0, 0),
        ),
      );

      expect(line, isNot(startsWith('tracer:')));
      expect(line, contains('INFO'));
      expect(line, contains('hello'));
    });
  });

  group('ConsoleSink tag filtering', () {
    test('skips records that do not match filterTag', () {
      final accepted = <String>[];
      final rejected = <String>[];
      final sink = ConsoleSink(
        colorize: false,
        filterTag: 'keep',
        out: _CollectingSink(accepted),
        err: _CollectingSink(rejected),
      );

      sink.write(
        LogRecord(
          level: LogLevel.info,
          message: 'kept',
          timestamp: DateTime(2026, 8, 3),
          tag: 'keep',
        ),
      );
      sink.write(
        LogRecord(
          level: LogLevel.info,
          message: 'dropped',
          timestamp: DateTime(2026, 8, 3),
          tag: 'other',
        ),
      );

      expect(accepted, hasLength(1));
      expect(accepted.single, contains('kept'));
      expect(accepted.single, isNot(contains('dropped')));
      expect(rejected, isEmpty);
    });

    test('accepts any of multiple filterTags', () {
      final lines = <String>[];
      final sink = ConsoleSink(
        colorize: false,
        filterTags: ['auth', 'checkout'],
        out: _CollectingSink(lines),
      );

      sink.write(_record('auth', 'a'));
      sink.write(_record('noise', 'b'));
      sink.write(_record('checkout', 'c'));

      expect(lines, hasLength(2));
      expect(lines[0], contains('a'));
      expect(lines[1], contains('c'));
    });
  });

  group('FileSink tag filtering', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tracerx_filter_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writeCount and persisted JSON only include matching tags', () async {
      final sink = FileSink(
        directory: tempDir.path,
        filterTag: 'network',
      );
      final session = TracerSession('mixed', sinks: [sink]);

      session.info('http ok', tag: 'network');
      session.info('ui click', tag: 'ui');
      session.debug('retry', tag: 'network');

      expect(sink.writeCount, 2);

      final trace = await session.end();
      await sink.flush();

      // Session still holds every event; the file is filtered.
      expect(trace.events, hasLength(3));

      final file = File('${tempDir.path}/mixed.tracer.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final events = json['events'] as List;

      expect(events, hasLength(2));
      expect(events.every((e) => e['tag'] == 'network'), isTrue);
    });
  });

  group('TraceEvent tag backward compatibility', () {
    test('defaults tag to session name and round-trips through JSON', () async {
      final session = TracerSession('checkout', sinks: [_NoopSink()]);
      session.info('started');
      final trace = await session.end();

      expect(trace.events.single.tag, 'checkout');

      final restored = TracerTrace.fromJsonString(trace.toJsonString());
      expect(restored.events.single.tag, 'checkout');
    });

    test('per-call tag overrides session name', () {
      final session = TracerSession('checkout', sinks: [_NoopSink()]);
      session.info('paid', tag: 'payments');
      expect(session.events.single.tag, 'payments');
    });

    test('legacy JSON without tag field still loads', () {
      final event = TraceEvent.fromJson({
        'timestamp': '2026-01-01T00:00:00.000Z',
        'level': 'info',
        'message': 'legacy',
      });
      expect(event.tag, isNull);
      expect(event.message, 'legacy');
    });
  });
}

LogRecord _record(String tag, String message) => LogRecord(
      level: LogLevel.info,
      message: message,
      timestamp: DateTime(2026, 8, 3),
      tag: tag,
    );

class _CollectingSink implements IOSink {
  _CollectingSink(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = '']) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoopSink implements LogSink {
  @override
  void write(LogRecord record) {}
}
