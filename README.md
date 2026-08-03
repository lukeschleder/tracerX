```markdown
# TracerX

**TracerX** is a high-performance, zero-dependency structured logging and execution-tracing package for Dart and Flutter. It captures precise runtime telemetry, logs lifecycle events across distinct severity levels, and performs automatic fix regression diffing (`TracerDiff`) to generate concrete, text-based fix receipts.

---

## Features

- **Structured Logging:** Capture logs with multi-level severity (`INFO`, `DEBUG`, `ERROR`) and rich metadata payloads.
- **Session Tracking:** Isolate logs into distinct execution sessions (e.g., bug sessions vs. fixed sessions).
- **TracerDiff & Fix Receipts:** Automatically compare execution paths between a baseline bug trace and a fixed target trace to quantify added (`[+]`), removed (`[-]`), or modified (`[!]`) execution steps.
- **Flexible Sinks:** Built-in support for live colorized console output and async file-based storage.
- **PII Masking:** Automatic redaction for sensitive keys like `email`, `token`, or `password`.

---

## Core Concepts

| Component | Role |
| --- | --- |
| `TracerX.startSession` | Opens a named recording session |
| `TracerSession` | Collects ordered `TraceEvent`s and fans out to configured sinks |
| `TraceEvent.metadata` | Key-value JSON state snapshot at a specific checkpoint |
| `TracerTrace` | Exportable JSON document containing the complete session recording |
| `TracerDiff` | LCS alignment engine that compares two `TracerTrace` sessions |
| `ConsoleSink` | Live colorized console logger with support for custom prefixes (e.g., `tracer:`) |
| `FileSink` | Async non-blocking file sink for persistent disk storage |
| `PiiMasker` | Automatic redactor for sensitive keys (`email`, `token`, `password`, etc.) |

---

## Installation

Add `tracer_x` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  tracer_x:
    path: ./path/to/tracer_x

```

---

## Usage

Here is a quick example of how to record sessions, print colorized diff output, and generate a fix receipt:

```dart
import 'dart:io';
import 'package:tracer_x/tracer_x.dart';

Future<void> main() async {
  final outputDir = Directory('./logs');
  await outputDir.create(recursive: true);

  // 1. Record baseline bug session
  final baseline = await recordBugSession(outputDir);

  // 2. Record fixed session
  final fixed = await recordFixedSession(outputDir);

  // 3. Generate diff and print ANSI-colorized output to terminal
  final diff = TracerDiff(baseline: baseline, target: fixed);
  stdout.write(diff.generateReceipt(colorize: true));

  // 4. Save clean plain-text receipt to disk
  await diff.saveReceipt('${outputDir.path}/fix_receipt.txt');
}

```

---

## Console Colors & Filtering

`ConsoleSink` and `TracerDiff.generateReceipt()` automatically apply ANSI colors when `stdout` is connected to a TTY.

```dart
// Explicitly control ANSI colorization and prefixes
ConsoleSink(colorize: true, prefix: 'tracer:');
diff.generateReceipt(colorize: true); // Terminal view with colors
diff.saveReceipt('receipt.txt');      // Always saves clean plain text

```

---

## Example Run

To run the included example walkthrough:

```bash
dart run example/example.dart

```

---

## Running Tests

Execute the package test suite to verify functionality:

```bash
dart test

```

---

## License

Distributed under the MIT License. See `LICENSE` for details.

```

```
