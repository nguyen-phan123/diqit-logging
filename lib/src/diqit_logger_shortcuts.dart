import 'package:diqit_logging/src/diqit_logging.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/logger/trace_id.dart';
import 'package:logger/logger.dart';

/// Extension methods adding canonical shortcut logging to DiqitLogger instances.
///
/// This allows child loggers to use the same concise API as static shortcuts:
/// ```dart
/// final logger = DiqitLogger.root.createChild('kds');
/// logger.t('Trace message');  // ✅ Works via extension
/// logger.d('Debug info');     // ✅ Works via extension
/// logger.i('Info message');   // ✅ Works via extension
/// ```
extension DiqitLoggerShortcuts on DiqitLogger {
  /// Logs a trace message using shorthand printer.
  void t(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) => log(Level.trace, message,
      data: data, tag: tag,
      traceId: traceId, context: context);

  /// Logs a debug message using shorthand printer.
  void d(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) => log(Level.debug, message,
      data: data, tag: tag,
      traceId: traceId, context: context);

  /// Logs an info message using shorthand printer.
  void i(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) => log(Level.info, message,
      data: data, tag: tag,
      traceId: traceId, context: context);

  /// Logs a warning message using shorthand printer.
  void w(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) => log(Level.warning, message,
      data: data, tag: tag,
      traceId: traceId, context: context);

  /// Logs an error message using shorthand printer.
  void e(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) => log(Level.error, message,
      data: data, tag: tag,
      error: error, stackTrace: stackTrace,
      traceId: traceId, context: context);

  /// Logs a fatal message using shorthand printer.
  void ft(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) => log(Level.fatal, message,
      data: data, tag: tag,
      error: error, stackTrace: stackTrace,
      traceId: traceId, context: context);
}
