/// ANSI escape codes and helpers for terminal styling.
///
/// Respects the `NO_COLOR` convention when callers use [AnsiColors.wrap]
/// together with an explicit [enabled] flag (typically derived from
/// `stdout.hasTerminal`).
class AnsiColors {
  AnsiColors._();

  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';

  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const white = '\x1B[37m';
  static const gray = '\x1B[90m';

  /// Wraps [text] in [code] … [reset] when [enabled] is true.
  static String wrap(String text, String code, {required bool enabled}) {
    if (!enabled) return text;
    return '$code$text$reset';
  }
}
