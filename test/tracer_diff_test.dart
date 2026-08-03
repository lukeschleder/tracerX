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
      systemInfo: const SystemInfo(
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
      expect(diff.generateReceipt(colorize: false), contains('[-] Baseline'));
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
      expect(diff.generateReceipt(colorize: false), contains('[+] Fixed'));
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
      final receipt = diff.generateReceipt(colorize: false);
      expect(receipt, contains('[!] Altered'));
      expect(receipt, contains('status: 500 → 200'));
      expect(receipt, contains('total: 0 → 99.99'));
    });

    test('reports identical traces with no differences', () {
      final events = [
        _event(className: 'App', method: 'run', message: 'Started'),
      ];

      final diff = TracerDiff(
        baseline: _trace('a', events),
        target: _trace('b', List.of(events)),
      );

      expect(diff.entries, isEmpty);
      expect(
        diff.generateReceipt(colorize: false),
        contains('No differences detected'),
      );
    });

    test('handles empty baseline and non-empty target', () {
      final diff = TracerDiff(
        baseline: _trace('empty', []),
        target: _trace('fixed', [
          _event(className: 'A', method: 'm', message: 'first'),
        ]),
      );

      expect(diff.entries, hasLength(1));
      expect(diff.entries.single.type, DiffType.added);
    });

    test('colorized receipt includes ANSI codes when forced on', () {
      final diff = TracerDiff(
        baseline: _trace('bug', [
          _event(className: 'A', method: 'm', message: 'x'),
        ]),
        target: _trace('fixed', [
          _event(className: 'A', method: 'm', message: 'x'),
          _event(className: 'B', method: 'n', message: 'y'),
        ]),
      );

      final colored = diff.generateReceipt(colorize: true);
      final plain = diff.generateReceipt(colorize: false);

      expect(colored, contains(AnsiColors.green));
      expect(colored, contains(AnsiColors.reset));
      expect(plain, isNot(contains('\x1B[')));
    });

    test('saveReceipt writes plain-text report to disk', () async {
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
      final saved = File(path).readAsStringSync();

      expect(saved, contains('TracerX Fix Receipt'));
      expect(saved, contains('[+] Fixed'));
      expect(saved, isNot(contains('\x1B[')));
      await dir.delete(recursive: true);
    });

    test('round-trips traces through JSON before diffing', () {
      final original = _trace('bug', [
        _event(
          className: 'Cart',
          method: 'checkout',
          message: 'Submit',
          metadata: {'status': 500},
        ),
      ]);

      final restored = TracerTrace.fromJsonString(original.toJsonString());
      final fixed = _trace('fixed', [
        _event(
          className: 'Cart',
          method: 'checkout',
          message: 'Submit',
          metadata: {'status': 200},
        ),
      ]);

      final diff = TracerDiff(baseline: restored, target: fixed);
      expect(diff.entries.single.type, DiffType.modified);
    });
  });
}
