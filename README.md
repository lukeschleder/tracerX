# TracerX

TracerX helps you **record what your code did**, then **compare a buggy run to a fixed run**.

You leave checkpoints in important places (like “checkout started” or “payment failed”). Each checkpoint can carry a small snapshot of state — status codes, totals, flags, and so on. TracerX saves those checkpoints in order. Later, it lines up two recordings and prints a short **Fix Receipt** showing what disappeared, what showed up, and what data changed.

No secret wrapping of your whole app. You choose the checkpoints.

---

## What you get

- **Checkpoints with levels** — `debug`, `info`, and `error`, plus optional state data
- **Sessions** — record a buggy flow and a fixed flow as separate named runs
- **Fix Receipts** — a readable before/after report (`[-]` removed, `[+]` added, `[!]` changed)
- **Console + file output** — live colorized logs, plus `.tracer.json` files on disk
- **Prefixes & tag filters** — brand console lines (`tracer: …`) and only keep the tags you care about
- **PII masking** — blanks out common secrets like `email`, `token`, and `password`
- **Zero runtime dependencies** — pure Dart; works in Dart and Flutter projects

---

## Install

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  tracer_x:
    path: ../tracerX   # or your git / pub URL
```

Then:

```bash
dart pub get
```

---

## Quick start

Record a buggy session, record a fixed session, then print the receipt:

```dart
import 'dart:io';
import 'package:tracer_x/tracer_x.dart';

Future<TracerTrace> recordBug(Directory dir) async {
  final session = TracerX.startSession(
    'checkout-bug',
    sinks: [
      ConsoleSink(colorize: true, prefix: 'tracer: '),
      FileSink(directory: dir.path),
    ],
  );

  session.info('Checkout started', metadata: {'itemCount': 2, 'status': 'idle'});
  session.debug('Subtotal calculated', metadata: {'subtotal': 50.0});
  session.error(
    'Order confirmed with possible stock violation',
    metadata: {'status': 'confirmed', 'total': 45.0},
  );

  return session.end();
}

Future<TracerTrace> recordFix(Directory dir) async {
  final session = TracerX.startSession(
    'checkout-fixed',
    sinks: [
      ConsoleSink(colorize: true, prefix: 'tracer: '),
      FileSink(directory: dir.path),
    ],
  );

  session.info('Checkout started', metadata: {'itemCount': 2, 'status': 'idle'});
  session.debug('Subtotal calculated', metadata: {'subtotal': 50.0});
  session.info(
    'Stock validation failed',
    metadata: {'status': 'rejected', 'outOfStock': ['HAT-014']},
  );

  return session.end();
}

Future<void> main() async {
  final dir = Directory('./traces')..createSync(recursive: true);

  final baseline = await recordBug(dir);
  final fixed = await recordFix(dir);

  final diff = TracerDiff(baseline: baseline, target: fixed);
  stdout.write(diff.generateReceipt(colorize: true));
  await diff.saveReceipt('${dir.path}/fix_receipt.txt');
}
```

A fuller checkout walkthrough lives in `example/example.dart`.

---

## How the pieces fit together

| Piece | Plain-English role |
| --- | --- |
| `TracerX.startSession` | Starts a named recording |
| `TracerSession` | Holds checkpoints in order and sends them to sinks |
| `TraceEvent` | One checkpoint (message, level, where it came from, optional tag + state) |
| `TraceEvent.metadata` | The state snapshot at that moment |
| `TracerTrace` | The full recording you can save or reload as JSON |
| `TracerDiff` | Compares two recordings and builds the Fix Receipt |
| `ConsoleSink` | Prints live, colorized lines to the terminal |
| `FileSink` | Saves the recording to disk when the session ends |
| `PiiMasker` | Redacts sensitive fields before they hit the console or file |
| `Tracer` | Simple day-to-day logger when you don’t need a full session |

---

## Colors, prefixes, and filters

Colors turn on automatically when you’re in a real terminal (and `NO_COLOR` is not set). You can force them either way.

```dart
ConsoleSink(
  colorize: true,
  prefix: 'tracer: ',          // every line starts with this
  filterTag: 'checkout',       // only print this tag
  // filterTags: ['checkout', 'payments'],
);

diff.generateReceipt(colorize: true);  // color in the terminal
diff.saveReceipt('receipt.txt');       // always plain text on disk
```

Tags default to the session name. Override per call when you want finer control:

```dart
session.info('Payment authorized', tag: 'payments');
```

`FileSink` supports the same `filterTag` / `filterTags` options. Filtering only affects what that sink writes — the session still keeps the full in-memory list.

---

## How the Fix Receipt works

1. You record checkpoints during a buggy run.
2. You fix the bug and record checkpoints again.
3. TracerX lines up steps that share the same level + message.
4. It reports:
   - **`[-]`** steps only in the buggy run
   - **`[+]`** steps only in the fixed run
   - **`[!]`** shared steps whose state data changed

Shared, unchanged steps stay quiet. The receipt focuses on what the fix actually changed.

---

## Try the example

```bash
dart run example/example.dart
```

## Run tests

```bash
dart analyze --fatal-infos
dart test
```

---

## License

MIT. See [LICENSE](LICENSE).
