import 'package:logger/logger.dart';

/// SDK-owned log level enum.
///
/// Decouples public API from the underlying `logger` package, so the
/// implementation can change without breaking SDK consumers.
enum GBLogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  off,
}

Level toLoggerLevel(GBLogLevel level) {
  switch (level) {
    case GBLogLevel.verbose:
      return Level.trace;
    case GBLogLevel.debug:
      return Level.debug;
    case GBLogLevel.info:
      return Level.info;
    case GBLogLevel.warning:
      return Level.warning;
    case GBLogLevel.error:
      return Level.error;
    case GBLogLevel.off:
      return Level.off;
  }
}
