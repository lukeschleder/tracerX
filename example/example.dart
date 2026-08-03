import 'dart:io';

import 'package:tracer_x/tracer_x.dart';

/// Simulates a buggy authentication flow.
Future<TracerTrace> recordBugSession(Directory outputDir) async {
  final fileSink = FileSink(directory: outputDir.path);

  final session = TracerX.startSession(
    'bug-session',
    sinks: [ConsoleSink(colorize: false), fileSink],
  );

  session.info(
    'Attempting login',
    metadata: {'email': 'user@example.com', 'status': 401},
  );
  session.debug('Validating credentials');
  session.error(
    'Authentication failed',
    metadata: {'reason': 'invalid_token', 'status': 401},
  );

  return session.end();
}

/// Simulates the fixed authentication flow.
Future<TracerTrace> recordFixedSession(Directory outputDir) async {
  final fileSink = FileSink(directory: outputDir.path);

  final session = TracerX.startSession(
    'fixed-session',
    sinks: [ConsoleSink(colorize: false), fileSink],
  );

  session.info(
    'Attempting login',
    metadata: {'email': 'user@example.com', 'status': 200},
  );
  session.debug('Validating credentials');
  session.info(
    'Refreshing token',
    metadata: {'status': 200},
  );
  session.info(
    'Login succeeded',
    metadata: {'status': 200},
  );

  return session.end();
}

Future<void> main() async {
  final outputDir = Directory('${Directory.systemTemp.path}/tracerx_example');
  if (outputDir.existsSync()) {
    await outputDir.delete(recursive: true);
  }
  await outputDir.create(recursive: true);

  stdout.writeln('=== Recording baseline (bug) session ===');
  final baseline = await recordBugSession(outputDir);

  stdout.writeln('\n=== Recording fixed session ===');
  final fixed = await recordFixedSession(outputDir);

  stdout.writeln('\n=== TracerDiff Fix Receipt ===\n');
  final diff = TracerDiff(baseline: baseline, target: fixed);
  stdout.write(diff.generateReceipt());

  final receiptPath = '${outputDir.path}/fix_receipt.txt';
  await diff.saveReceipt(receiptPath);
  stdout.writeln('\nReceipt saved to: $receiptPath');
  stdout.writeln('Traces saved to: ${outputDir.path}');
}
