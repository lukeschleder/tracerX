# tracerX

Structured execution tracing and golden-master **Fix Receipts** for Dart.

Record a buggy flow, record the fixed flow, then diff the two traces to see
exactly which checkpoints disappeared, appeared, or changed state.

```text
=== TracerX Fix Receipt ===
Baseline: checkout-bug
Target:   checkout-fixed
Events:   4 → 4

[-] Baseline: CheckoutService.placeOrderBuggy — Order confirmed with possible stock violation
[+] Fixed: CheckoutService.placeOrderFixed — Stock validation failed
[!] Altered: CheckoutService.… — Checkout started
    status: idle → idle   (and payload field diffs)
```

## Why it exists

Most loggers dump lines. tracerX treats a session as an **ordered sequence of
state checkpoints**. That makes “did my fix change the execution path?” a
deterministic comparison problem instead of a scroll-through-the-console problem.

## Install

```yaml
dependencies:
  tracer_x:
    git:
      url: https://github.com/lukeschleder/tracerX.git
      ref: feature/tracerx-initial-impl 
```

```bash
dart pub get
```

## Quick start

```dart
import 'package:tracer_x/tracer_x.dart';

Future<void> main() async {
  final session = TracerX.startSession(
    'login',
    sinks: [ConsoleSink(), FileSink(directory: 'traces')],
  );

  session.info('Authenticating', metadata: {'email': 'a@b.com', 'status': 401});
  session.error('Auth failed', metadata: {'reason': 'invalid_token'});

  final bugTrace = await session.end();

  // …fix the bug, re-run into another session, then:
  // final diff = TracerDiff(baseline: bugTrace, target: fixedTrace);
  // print(diff.generateReceipt());
}
```

## Core concepts

| Type | Role |
|------|------|
| `TracerX.startSession` | Opens a named recording session |
| `TracerSession` | Collects ordered `TraceEvent`s + fans out to sinks |
| `TraceEvent.metadata` | Your JSON state snapshot at that checkpoint |
| `TracerTrace` | Exportable `.tracer.json` document |
| `TracerDiff` | LCS alignment + metadata diff → Fix Receipt |
| `ConsoleSink` / `FileSink` | Colorized live output / async disk persistence |
| `PiiMasker` | Redacts `email`, `token`, `password`, etc. |

Day-to-day logging without export uses `Tracer` (same sink model, no session).

## Colors

`ConsoleSink` and `TracerDiff.generateReceipt()` apply ANSI colors when stdout
is a TTY and `NO_COLOR` is unset. Force either way:

```dart
ConsoleSink(colorize: true);
diff.generateReceipt(colorize: true);   // terminal
diff.saveReceipt('receipt.txt');        // always plain text
```

## Example

```bash
dart run example/example.dart
```

Walks a buggy vs fixed checkout flow and prints a colorized Fix Receipt.

## Tests

```bash
dart analyze --fatal-infos
dart test
```

## License

MIT
