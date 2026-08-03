import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tracer_x/tracer_x.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tracerx_filesink_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FileSink', () {
    test('persists masked trace JSON asynchronously', () async {
      final sink = FileSink(directory: tempDir.path);
      final session = TracerSession('pii-test', sinks: [sink]);

      session.info(
        'User login',
        metadata: {
          'email': 'user@example.com',
          'password': 'secret123',
          'token': 'abc-def',
        },
      );

      final trace = await session.end();
      await sink.flush();

      final file = File('${tempDir.path}/pii-test.tracer.json');
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final metadata =
          (json['events'] as List).first['metadata'] as Map<String, dynamic>;

      expect(metadata['email'], '***REDACTED***');
      expect(metadata['password'], '***REDACTED***');
      expect(metadata['token'], '***REDACTED***');
      expect(trace.events, hasLength(1));
    });

    test('writes 1000+ rapid entries without dropping events', () async {
      final sink = FileSink(
        directory: tempDir.path,
        fileName: 'stress.tracer.json',
      );
      final session = TracerSession('stress', sinks: [sink]);

      for (var i = 0; i < 1200; i++) {
        session.info('event-$i', metadata: {'index': i, 'status': i % 2});
      }

      expect(sink.bufferedCount, 1200);

      final trace = await session.end();
      await sink.flush();

      expect(trace.events, hasLength(1200));
      expect(sink.persistCount, 1);

      final file = File('${tempDir.path}/stress.tracer.json');
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final events = json['events'] as List;
      expect(events, hasLength(1200));
      expect(events.first['message'], 'event-0');
      expect(events.last['message'], 'event-1199');
    });

    test('does not block while buffering high-volume I/O', () async {
      final sink = FileSink(
        directory: tempDir.path,
        fileName: 'async-io.tracer.json',
      );
      final session = TracerSession('async-io', sinks: [sink]);
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 1000; i++) {
        session.info('event-$i', metadata: {'index': i});
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      final trace = await session.end();
      await sink.flush();

      expect(trace.events, hasLength(1000));
      expect(sink.bufferedCount, 1000);

      final file = File('${tempDir.path}/async-io.tracer.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect((json['events'] as List).length, 1000);
    });
  });

  group('PiiMasker', () {
    test('redacts sensitive keys and email patterns in strings', () {
      final masked = PiiMasker.mask({
        'username': 'luke',
        'api_key': 'xyz',
        'note': 'Contact me at user@example.com',
      }) as Map;

      expect(masked['username'], 'luke');
      expect(masked['api_key'], '***REDACTED***');
      expect(masked['note'], contains('***REDACTED***'));
    });
  });
}
