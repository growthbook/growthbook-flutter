import 'package:logger/logger.dart';

class DynamicLogFilter extends LogFilter {
  Level? _level;

  DynamicLogFilter(Level level) : _level = level;

  @override
  Level? get level => _level;

  @override
  set level(Level? newLevel) {
    _level = newLevel;
  }

  @override
  bool shouldLog(LogEvent event) {
    // якщо рівень не заданий — логувати все
    if (_level == null) return true;
    return event.level.index >= _level!.index;
  }
}

final logFilter = DynamicLogFilter(Level.info);

final logger = Logger(
  filter: logFilter,
  printer: PrettyPrinter(colors: false, methodCount: 0, errorMethodCount: 2, printEmojis: false),  
);

