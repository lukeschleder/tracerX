/// Parsed caller location extracted from a [StackTrace] frame.
class CallerInfo {
  const CallerInfo({
    required this.file,
    required this.line,
    this.className,
    this.methodName,
  });

  final String file;
  final int line;
  final String? className;
  final String? methodName;

  String get qualifiedName {
    if (className != null && methodName != null) {
      return '$className.$methodName';
    }
    return methodName ?? className ?? '<unknown>';
  }
}
