/// Parsed caller location extracted from a [StackTrace] frame.
class CallerInfo {
  /// Creates caller location metadata.
  const CallerInfo({
    required this.file,
    required this.line,
    this.className,
    this.methodName,
  });

  /// Shortened file URI or package path.
  final String file;

  /// 1-based source line number.
  final int line;

  /// Declaring class, if the frame was an instance/static method.
  final String? className;

  /// Method or top-level function name.
  final String? methodName;

  /// `Class.method`, or the best available fallback.
  String get qualifiedName {
    if (className != null && methodName != null) {
      return '$className.$methodName';
    }
    return methodName ?? className ?? '<unknown>';
  }
}
