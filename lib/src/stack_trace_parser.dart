import 'caller_info.dart';

/// Parses Dart stack traces to locate the first caller outside this package.
class StackTraceParser {
  StackTraceParser._();

  static const _packagePrefix = 'package:tracer_x/';

  static final _framePattern = RegExp(
    r'^\#\d+\s+(.+?)\s+\((.+?):(\d+)(?::\d+)?\)',
  );

  /// Returns caller file, line, class, and method of the first external frame.
  static CallerInfo? parseCaller(StackTrace stackTrace) {
    for (final frame in stackTrace.toString().split('\n')) {
      if (_isInternalFrame(frame)) continue;

      final match = _framePattern.firstMatch(frame.trim());
      if (match == null) continue;

      final symbol = match.group(1)!;
      final uri = match.group(2)!;
      final line = int.parse(match.group(3)!);
      final names = _parseSymbol(symbol);

      return CallerInfo(
        file: _shortenPath(uri),
        line: line,
        className: names.className,
        methodName: names.methodName,
      );
    }

    return null;
  }

  static ({String? className, String? methodName}) _parseSymbol(String symbol) {
    final dotIndex = symbol.lastIndexOf('.');
    if (dotIndex <= 0) {
      return (className: null, methodName: symbol);
    }

    final className = symbol.substring(0, dotIndex);
    final methodName = symbol.substring(dotIndex + 1);

    // Top-level closures like main.<anonymous closure>
    if (className == 'main' && methodName.startsWith('<')) {
      return (className: null, methodName: symbol);
    }

    return (className: className, methodName: methodName);
  }

  static bool _isInternalFrame(String frame) {
    return frame.contains(_packagePrefix) ||
        frame.contains('Tracer._log') ||
        frame.contains('Tracer.info') ||
        frame.contains('Tracer.debug') ||
        frame.contains('Tracer.error') ||
        frame.contains('TracerSession._log') ||
        frame.contains('TracerSession.info') ||
        frame.contains('TracerSession.debug') ||
        frame.contains('TracerSession.error');
  }

  static String _shortenPath(String uri) {
    const filePrefix = 'file://';
    if (uri.startsWith(filePrefix)) {
      return uri.substring(filePrefix.length);
    }

    const packagePrefix = 'package:';
    if (uri.startsWith(packagePrefix)) {
      return uri.substring(packagePrefix.length);
    }

    return uri;
  }
}
