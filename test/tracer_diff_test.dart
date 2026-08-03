import 'dart:io';

import 'package:test/test.dart';
import 'package:tracer_x/tracer_x.dart';

TraceEvent _event({
  required String className,
  required String method,
  required String message,
  Map<String, dynamic>? metadata,
  LogLevel level = LogLevel.info,
}) =>
    TraceEvent(
      timestamp: DateTime(2026, 1, 1),
      level: level,
      message: message,
      className: className,
      methodName: method,
      metadata: metadata,
    );

TracerTrace _trace(String name, List<TraceEvent> events) => TracerTrace(
      sessionName: name,
      startedAt: DateTime(2026, 1, 1),
      systemInfo: SystemInfo(
        os: 'test',
        osVersion: '1.0',
        pid: 1,
        dartVersion: '3.0.0',
      ),
      events: events,
    );

void main() {
  group('TracerDiff', () {
    test('detects removed baseline events', () {
      final baseline = _trace('bug', [
        _event(
          className: 'AuthService',
          method: 'login',
          message: 'Attempt login',
          metadata: {'status': 401},
        ),
        _event(
          className: 'AuthService',
          method: 'fail',
          message: 'Login failed',
        ),
      ]);

      final target = _trace('fixed', [
        _event(
          className: 'AuthService',
          method: 'login',
          message: 'Attempt login',
          metadata: {'status': 200},
        ),
      ]);

      final diff = TracerDiff(baseline: baseline, target: target);
      final removed = diff.entries.where((e) => e.type == DiffType.removed);

      expect(removed, hasLength(1));
      expect(removed.first.baselineEvent!.methodName, 'fail');
      expect(diff.generateReceipt(), contains('[-] Baseline'));
    });

    test('detects added fixed-path events', () {
      final baseline = _trace('bug', [
        _event(
          className: 'AuthService',
          method: 'login',
          message: 'Attempt login',
        ),
      ]);

      final target = _trace('fixed', [
        _event(
          className: 'AuthService',
          method: 'login',
          message: 'Attempt login',
        ),
        _event(
          className: 'AuthService',
          method: 'refreshToken',
          message: 'Token renewed',
        ),
      ]);

      final diff = TracerDiff(baseline: baseline, target: target);
      final added = diff.entries.where((e) => e.type == DiffType.added);

      expect(added, hasLength(1));
      expect(added.first.targetEvent!.methodName, 'refreshToken');
      expect(diff.generateReceipt(), contains('[+] Fixed'));
    });

    test('detects altered state payloads', () {
      final baseline = _trace('bug', [
        _event(
          className: 'OrderService',
          method: 'submit',
          message: 'Submit order',
          metadata: {'status': 500, 'total': 0},
        ),
      ]);

      final target = _trace('fixed', [
        _event(
          className: 'OrderService',
          method: 'submit',
          message: 'Submit order',
          metadata: {'status': 200, 'total': 99.99},
        ),
      ]);

      final diff = TracerDiff(baseline: baseline, target: target);
      final modified = diff.entries.where((e) => e.type == DiffType.modified);

      expect(modified, hasLength(1));
      expect(diff.generateReceipt(), contains('[!] Altered'));
      expect(diff.generateReceipt(), contains('status: 500 → 200'));
      expect(diff.generateReceipt(), contains('total: 0 → 99.99'));
    });

    test('reports identical traces with no differences', () {
      final events = [
        _event(
          className: 'App',
          method: 'run',
          message: 'Started',
        ),
      ];

      final diff = TracerDiff(
        baseline: _trace('a', events),
        target: _trace('b', events),
      );

      expect(diff.entries, isEmpty);
      expect(diff.generateReceipt(), contains('No differences detected'));
    });

    test('saveReceipt writes report to disk', () async {
      final baseline = _trace('bug', [
        _event(className: 'A', method: 'm', message: 'x'),
      ]);
      final target = _trace('fixed', [
        _event(className: 'A', method: 'm', message: 'x'),
        _event(className: 'B', method: 'n', message: 'y'),
      ]);

      final diff = TracerDiff(baseline: baseline, target: target);
      final dir = Directory.systemTemp.createTempSync('tracerx_receipt_');
      final path = '${dir.path}/receipt.txt';

      await diff.saveReceipt(path);

      expect(File(path).readAsStringSync(), contains('TracerX Fix Receipt'));
      expect(File(path).readAsStringSync(), contains('[+] Fixed'));
      await dir.delete(recursive: true);
    });
  });
}
