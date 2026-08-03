import 'package:test/test.dart';
import 'package:tracer_x/tracer_x.dart';

void main() {
  group('TracerSession', () {
    test('records events and exports TracerTrace JSON', () async {
      final session = TracerX.startSession(
        'unit-test',
        sinks: [_CapturingSink()],
      );

      session.info('hello', metadata: {'step': 1});
      session.debug('detail');
      session.error('failure', metadata: {'status': 500});

      final trace = await session.end();

      expect(trace.sessionName, 'unit-test');
      expect(trace.events, hasLength(3));
      expect(trace.events.first.message, 'hello');
      expect(trace.events.first.metadata, {'step': 1});
      expect(trace.endedAt, isNotNull);
      expect(session.isClosed, isTrue);

      final json = trace.toJson();
      expect(json['sessionName'], 'unit-test');
      expect(json['events'], hasLength(3));
      expect(json['systemInfo'], isA<Map<String, dynamic>>());
    });

    test('throws when logging after end', () async {
      final session = TracerSession('closed', sinks: [_CapturingSink()]);
      await session.end();
      expect(() => session.info('too late'), throwsStateError);
    });

    test('copies metadata so callers cannot mutate recorded events', () {
      final session = TracerSession('meta', sinks: [_CapturingSink()]);
      final payload = <String, dynamic>{'status': 1};
      session.info('step', metadata: payload);
      payload['status'] = 999;
      expect(session.events.single.metadata!['status'], 1);
    });
  });

  group('Tracer with custom sink', () {
    test('routes log records to the configured sink', () {
      final records = <LogRecord>[];
      final log = Tracer(
        sink: _ListSink(records),
        minLevel: LogLevel.debug,
      );

      log.info('hello');

      expect(records, hasLength(1));
      expect(records.single.level, LogLevel.info);
      expect(records.single.message, 'hello');
    });

    test('respects minLevel filter', () {
      final records = <LogRecord>[];
      final log = Tracer(
        sink: _ListSink(records),
        minLevel: LogLevel.info,
      );

      log.debug('hidden');
      log.info('visible');

      expect(records, hasLength(1));
      expect(records.single.message, 'visible');
    });
  });

  group('ConsoleSink formatting', () {
    test('exposes colorize flag for forced styling', () {
      final sink = ConsoleSink(colorize: true);
      expect(sink.colorize, isTrue);
      expect(ConsoleSink(colorize: false).colorize, isFalse);
    });
  });
}

class _CapturingSink implements LogSink {
  @override
  void write(LogRecord record) {}
}

class _ListSink implements LogSink {
  _ListSink(this.records);

  final List<LogRecord> records;

  @override
  void write(LogRecord record) => records.add(record);
}
