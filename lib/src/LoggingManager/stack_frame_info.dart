import 'package:flutter/foundation.dart';

class StackFrameInfo {
  final String file;
  final int line;
  final int column;
  final String function;

  const StackFrameInfo({
    required this.file,
    required this.line,
    required this.column,
    required this.function,
  });

  @override
  String toString() {
    return '[$file:$line:$column] $function';
  }
}

StackFrameInfo? extractStackInfo([StackTrace? stackTrace, int level = 1]) {
  final trace = stackTrace ?? StackTrace.current;
  final traceLines = trace.toString().trim().split('\n');

  if (traceLines.length <= level) return null;

  final line = traceLines[level].trim();

  if (kIsWeb) {
    final regex = RegExp(r'^([^\s]+)\s+(\d+):(\d+)\s+(.*)$');
    final match = regex.firstMatch(line);

    if (match != null) {
      return StackFrameInfo(
        file: match.group(1) ?? '<unknown>',
        line: int.tryParse(match.group(2) ?? '') ?? 0,
        column: int.tryParse(match.group(3) ?? '') ?? 0,
        function: match.group(4)?.trim() ?? '<unknown>',
      );
    }

    final fallbackRegex = RegExp(r'^(.+?):(\d+)(?::(\d+))?$');
    final fallbackMatch = fallbackRegex.firstMatch(line);

    if (fallbackMatch != null) {
      return StackFrameInfo(
        file: fallbackMatch.group(1) ?? '<unknown>',
        line: int.tryParse(fallbackMatch.group(2) ?? '') ?? 0,
        column: int.tryParse(fallbackMatch.group(3) ?? '') ?? 0,
        function: '<unknown>',
      );
    }
  } else {
    final regex = RegExp(r'(?:#\d+\s+)?(.+?) \((.+?):(\d+):(\d+)\)');
    final match = regex.firstMatch(line);

    if (match != null) {
      final function = match.group(1)?.trim() ?? '<unknown>';
      final file = match.group(2)?.trim() ?? '<unknown>';
      final line = int.tryParse(match.group(3) ?? '') ?? 0;
      final column = int.tryParse(match.group(4) ?? '') ?? 0;

      return StackFrameInfo(
        file: file,
        line: line,
        column: column,
        function: function,
      );
    }
  }

  return null;
}
