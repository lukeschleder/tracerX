import 'package:test/test.dart';
import 'package:tracer_x/tracer_x.dart';

void main() {
  group('StackTraceParser', () {
    test('extracts file, line, class, and method from stack trace', () {
      final trace = StackTrace.fromString('''
#0      TracerSession._log (package:tracer_x/src/tracer_session.dart:72:5)
#1      TracerSession.info (package:tracer_x/src/tracer_session.dart:40:5)
#2      AuthService.login (package:my_app/auth_service.dart:42:3)
''');

      final caller = StackTraceParser.parseCaller(trace);

      expect(caller, isNotNull);
      expect(caller!.file, 'my_app/auth_service.dart');
      expect(caller.line, 42);
      expect(caller.className, 'AuthService');
      expect(caller.methodName, 'login');
      expect(caller.qualifiedName, 'AuthService.login');
    });

    test('handles top-level functions without a class', () {
      final trace = StackTrace.fromString('''
#0      Tracer._log (package:tracer_x/src/tracer.dart:50:5)
#1      main (file:///Users/dev/app/bin/main.dart:10:3)
''');

      final caller = StackTraceParser.parseCaller(trace);

      expect(caller!.className, isNull);
      expect(caller.methodName, 'main');
      expect(caller.file, '/Users/dev/app/bin/main.dart');
      expect(caller.line, 10);
    });

    test('handles async closure frames', () {
      final trace = StackTrace.fromString('''
#0      TracerSession._log (package:tracer_x/src/tracer_session.dart:72:5)
#1      main.<anonymous closure> (file:///Users/dev/app/bin/main.dart:15:7)
''');

      final caller = StackTraceParser.parseCaller(trace);

      expect(caller!.className, isNull);
      expect(caller.methodName, 'main.<anonymous closure>');
      expect(caller.line, 15);
    });

    test('skips internal tracer_x frames', () {
      final trace = StackTrace.fromString('''
#0      TracerSession._log (package:tracer_x/src/tracer_session.dart:72:5)
#1      someHelper (package:my_app/utils.dart:5:3)
''');

      final caller = StackTraceParser.parseCaller(trace);

      expect(caller!.file, 'my_app/utils.dart');
      expect(caller.line, 5);
    });
  });

  group('StackTraceParser async futures', () {
    test('captures caller through async gap', () async {
      CallerInfo? captured;
      await _asyncLog((info) => captured = info);
      expect(captured, isNotNull);
      expect(captured!.methodName, '_asyncLog');
    });
  });
}

Future<void> _asyncLog(void Function(CallerInfo info) callback) async {
  await Future<void>.delayed(Duration.zero);
  final info = StackTraceParser.parseCaller(StackTrace.current);
  if (info != null) callback(info);
}
