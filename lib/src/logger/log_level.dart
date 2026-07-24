import 'package:logger/logger.dart' as logger_pkg;

/// Log level enum that seals the logger package dependency.
///
/// Prevents leaky abstraction by wrapping logger.Level behind our own type.
/// Callers depend on DLogLevel, not on the underlying logger package.
enum DLogLevel {
  /// Trace level (most verbose)
  trace,

  /// Debug level
  debug,

  /// Info level
  info,

  /// Warning level
  warning,

  /// Error level
  error,

  /// Fatal level (least verbose, critical failures)
  fatal,

  /// All levels (used for filter bypass)
  all;

  /// Converts to underlying logger package Level
  logger_pkg.Level toLoggerLevel() {
    switch (this) {
      case DLogLevel.trace:
        return logger_pkg.Level.trace;
      case DLogLevel.debug:
        return logger_pkg.Level.debug;
      case DLogLevel.info:
        return logger_pkg.Level.info;
      case DLogLevel.warning:
        return logger_pkg.Level.warning;
      case DLogLevel.error:
        return logger_pkg.Level.error;
      case DLogLevel.fatal:
        return logger_pkg.Level.fatal;
      case DLogLevel.all:
        return logger_pkg.Level.all;
    }
  }

  /// Creates from underlying logger package Level
  static DLogLevel fromLoggerLevel(logger_pkg.Level level) {
    switch (level) {
      case logger_pkg.Level.trace:
        return DLogLevel.trace;
      case logger_pkg.Level.debug:
        return DLogLevel.debug;
      case logger_pkg.Level.info:
        return DLogLevel.info;
      case logger_pkg.Level.warning:
        return DLogLevel.warning;
      case logger_pkg.Level.error:
        return DLogLevel.error;
      case logger_pkg.Level.fatal:
        return DLogLevel.fatal;
      default:
        return DLogLevel.all;
    }
  }

  /// Returns numeric priority for comparison
  int get value => toLoggerLevel().value;
}
