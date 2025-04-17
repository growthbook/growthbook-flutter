import 'dart:developer' as developer;
import 'dart:async';
import 'package:growthbook_sdk_flutter/src/LoggingManager/formatter.dart';
import 'package:growthbook_sdk_flutter/src/LoggingManager/stack_frame_info.dart';

enum LogLevel {
  trace,
  debug,
  info,
  warning,
  error;

  String get description => name.toUpperCase();

  bool operator >=(LogLevel other) {
    return index >= other.index;
  }
}

Logger logger = Logger();

class Logger {
  bool _enabled;
  late Formatter _formatter;
  LogLevel _minLevel;

  static final Logger _instance = Logger._internal();

  factory Logger() => _instance;

  String get format => _formatter.description;
  Formatter get formatter => _formatter;

  set minLevel(LogLevel logLevel) {
    _minLevel = logLevel;
  }

  set enabled(bool enabled) {
    _enabled = enabled;
  }

  set formatter(Formatter newFormatter) {
    _formatter = newFormatter;
    _formatter.logger = this;
  }

  Logger._internal()
      : _formatter = FormatterTheme.defaultFormatter,
        _enabled = true,
        _minLevel = LogLevel.trace {
    _formatter.logger = this;
  }

  void trace(
    List<dynamic> items, {
    String separator = " ",
    String terminator = "\n",
    StackTrace? stackTrace,
  }) {
    log(level: LogLevel.trace, items: items, stackTrace: StackTrace.current);
  }

  void debug(
    List<dynamic> items, {
    String separator = " ",
    String terminator = "\n",
    StackTrace? stackTrace,
  }) {
    log(level: LogLevel.debug, items: items, stackTrace: StackTrace.current);
  }

  void info(
    List<dynamic> items, {
    String separator = " ",
    String terminator = "\n",
    StackTrace? stackTrace,
  }) {
    log(level: LogLevel.info, items: items, stackTrace: StackTrace.current);
  }

  void warning(
    List<dynamic> items, {
    String separator = " ",
    String terminator = "\n",
    StackTrace? stackTrace,
  }) {
    log(level: LogLevel.warning, items: items, stackTrace: StackTrace.current);
  }

  void error(
    List<dynamic> items, {
    String separator = " ",
    String terminator = "\n",
    StackTrace? stackTrace,
  }) {
    log(level: LogLevel.error, items: items, stackTrace: StackTrace.current);
  }

  void log({
    required LogLevel level,
    required List<dynamic> items,
    String separator = " ",
    String terminator = "\n",
    required StackTrace stackTrace,
  }) {
    if (_enabled && level >= _minLevel) {
      DateTime date = DateTime.now();
      StackFrameInfo? stackFrameInfo = extractStackInfo(stackTrace, 1);
      if (stackFrameInfo != null) {
        final res = _formatter.format(
          items: items,
          separator: separator,
          terminator: terminator,
          file: stackFrameInfo.file,
          format: '',
          line: stackFrameInfo.line,
          column: stackFrameInfo.column,
          function: stackFrameInfo.function,
          date: DateTime.now(),
          level: level,
        );
        Future.microtask(() {
          developer.log(res);
        });
      }
    }
  }
}
