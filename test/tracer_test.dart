import 'package:test/test.dart';
import 'package:tracer_x/tracer_x.dart';

void main() {
  group('TracerSession', () {
    test('records events and exports TracerTrace JSON', () async {
      final session = TracerX.startSession('unit-test');

      session.info('hello', metadata: {'step': 1});
      session.debug('detail');
      session.error('failure', metadata: {'status': 500});

      final trace = await session.end();

      expect(trace.sessionName, 'unit-test');
      expect(trace.events, hasLength(3));
      expect(trace.events.first.message, 'hello');
      expect(trace.events.first.metadata, {'step': 1});
      expect(trace.endedAt, isNotNull);

      final json = trace.toJson();
      expect(json['sessionName'], 'unit-test');
      expect(json['events'], hasLength(3));
      expect(json['systemInfo'], isA<Map<String, dynamic>>());
    });
  });

  group('Tracer with custom sink', () {
    test('routes log records to the configured sink', () {
      final records = <LogRecord>[];
      final log = Tracer(
        sink: _CapturingSink(records),
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
        sink: _CapturingSink(records),
        minLevel: LogLevel.info,
      );

      log.debug('hidden');
      log.info('visible');

      expect(records, hasLength(1));
      expect(records.single.message, 'visible');
    });
  });
}

class _CapturingSink implements LogSink {
  _CapturingSink(this.records);

  final List<LogRecord> records;

  @override
  void write(LogRecord record) => records.add(record);
}
