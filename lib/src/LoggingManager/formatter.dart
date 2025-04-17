import 'package:growthbook_sdk_flutter/src/LoggingManager/logging_manager.dart';

enum Component {
  date,
  message,
  level,
  file,
  line,
  column,
  function,
  location,
  block,
}

class Formatter {
  String formatStr;
  List<Component> components;
  late Logger logger;
  String dateFormat;
  bool fullPath, fileExtension;
  final Object? Function()? block;

  Formatter(
      {required this.formatStr,
      required this.components,
      this.dateFormat = "HH:mm:ss dd.MM.yyyy",
      this.fileExtension = false,
      this.fullPath = false,
      this.block});

  String get description => formatStr.replaceAllMapped(RegExp(r'%s'), (match) {
        final component = components.removeAt(0);
        return component.toString().toUpperCase();
      });

  String format({
    required String format,
    required LogLevel level,
    required List<dynamic> items,
    required String separator,
    required String terminator,
    required String file,
    required int line,
    required int column,
    required String function,
    required DateTime date,
  }) {
    final arguments = components.map((component) {
      switch (component) {
        case Component.date:
          return formatDate(date, dateFormat);
        case Component.file:
          return formatFile(file,
              fullPath: fullPath, fileExtension: fileExtension);
        case Component.function:
          return function;
        case Component.line:
          return line.toString();
        case Component.column:
          return column.toString();
        case Component.level:
          return formatLevel(level);
        case Component.message:
          return items.map((e) => e.toString()).join(separator);
        case Component.location:
          return formatLocation(file, line);
        case Component.block:
          return block?.call()?.toString() ?? '';
      }
    }).toList();

    var result = formatStr;
    for (final arg in arguments) {
      result = result.replaceFirst('%s', arg);
    }
    return result + terminator;
  }

  String formatWithDescription(
      {String? description,
      required double average,
      required double relativeStandardDeviation,
      required String file,
      required int line,
      required int column,
      required String function,
      required DateTime date}) {
    final arguments = components.map((component) {
      switch (component) {
        case Component.date:
          return formatDate(date, dateFormat);
        case Component.file:
          return formatFile(file,
              fullPath: fullPath, fileExtension: fileExtension);
        case Component.function:
          return function;
        case Component.line:
          return line.toString();
        case Component.column:
          return column.toString();
        case Component.level:
          return formatDescription(description);
        case Component.message:
          return formatTimeStats(average, relativeStandardDeviation);
        case Component.location:
          return formatLocation(file, line);
        case Component.block:
          return block?.call()?.toString() ?? '';
      }
    }).toList();
    var result = formatStr;
    for (final arg in arguments) {
      result = result.replaceFirst('%s', arg);
    }
    return result;
  }
}

extension FormatterHelper on Formatter {
  String formatDate(DateTime date, String dateFormat) {
    return dateFormat
        .replaceAll('yyyy', date.year.toString())
        .replaceAll('MM', date.month.toString().padLeft(2, '0'))
        .replaceAll('dd', date.day.toString().padLeft(2, '0'))
        .replaceAll('HH', date.hour.toString().padLeft(2, '0'))
        .replaceAll('mm', date.minute.toString().padLeft(2, '0'))
        .replaceAll('ss', date.second.toString().padLeft(2, '0'))
        .replaceAll('SSS', date.millisecond.toString().padLeft(3, '0'));
  }

  String formatFile(String file,
      {required bool fullPath, required bool fileExtension}) {
    if (!fullPath) {
      file = file.split('/').last;
    }
    if (!fileExtension) {
      final dotIndex = file.lastIndexOf('.');
      if (dotIndex != -1) {
        file = file.substring(0, dotIndex);
      }
    }
    return file;
  }

  String formatLocation(String file, int line) {
    final formattedFile =
        formatFile(file, fullPath: false, fileExtension: true);
    return '$formattedFile:$line';
  }

  String formatLevel(LogLevel level) {
    final text = level.description;
    return text;
  }

  String formatDescription(String? description) {
    String text = 'MEASURE';

    if (description != null) {
      text = '$text $description';
    }

    return text;
  }

  String formatTimeStats(double average, double relativeStandardDeviation) {
    final formattedAverage = formatAverage(average);
    final formattedStdev =
        formatRelativeStandardDeviation(relativeStandardDeviation);
    return 'Time: $formattedAverage sec ($formattedStdev STDEV)';
  }

  String formatAverage(double average) {
    return average.toStringAsFixed(3);
  }

  String formatDurations(List<double> durations) {
    final formatted = durations.map((d) => d.toStringAsFixed(6)).join(', ');
    return '[$formatted]';
  }

  String formatStandardDeviation(double standardDeviation) {
    return standardDeviation.toStringAsFixed(6);
  }

  String formatRelativeStandardDeviation(double relativeStandardDeviation) {
    return '${relativeStandardDeviation.toStringAsFixed(3)}%';
  }
}

extension FormatterTheme on Formatter {
  static Formatter get defaultFormatter => Formatter(
        formatStr: "[%s] %s %s: %s",
        components: [
          Component.date,
          Component.location,
          Component.level,
          Component.message,
        ],
      );

  static Formatter get minimal => Formatter(
        formatStr: "%s %s: %s",
        components: [
          Component.location,
          Component.level,
          Component.message,
        ],
      );

  static Formatter get detailed => Formatter(
        formatStr: "[%s] %s.%s:%s %s: %s",
        dateFormat: "yyyy-MM-dd HH:mm:ss.SSS",
        fileExtension: false,
        fullPath: false,
        components: [
          Component.date,
          Component.file,
          Component.function,
          Component.line,
          Component.level,
          Component.message,
        ],
      );
}
