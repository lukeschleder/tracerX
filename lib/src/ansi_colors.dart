/// ANSI escape codes for terminal color output.
class AnsiColors {
  AnsiColors._();

  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';

  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const cyan = '\x1B[36m';
  static const gray = '\x1B[90m';
  static const white = '\x1B[37m';
}
