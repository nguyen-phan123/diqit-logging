import 'package:diqit_logging/src/internal/file_log_manager.dart';
import 'package:diqit_logging/src/internal/log_history_manager.dart';
import 'package:diqit_logging/src/logger/logger.dart';
import 'package:logger/logger.dart';

/// {@template diqit_logging}
/// A singleton logger wrapper offering a unified logging interface.
///
/// Features:
/// - **Singleton**: Global access via static methods.
/// - **Tag Support**: Categorize logs with [LogTag].
/// - **Dual Printers**: Short methods (e.g., [t], [d]) use a minimal printer;
///   full methods (e.g., [trace], [debug]) use a detailed trace printer.
/// - **File Logging**: Optional file logging configured via [initialize].
///
/// Usage:
/// ```dart
/// await DiqitLogger.initialize(loggerConfig);
/// DiqitLogger.i('App started');
/// ```
/// {@endtemplate}
class DiqitLogger {
  /// {@macro diqit_logging}
  DiqitLogger();
  static final DiqitLogger _instance = DiqitLogger._();

  // * --- Configuration State ---
  late LoggerConfig _config;
  bool _initialized = false;

  // * --- internal Logger Instance ---
  Logger? _activeLogger;

  // * --- Helpers ---
  final _historyManager = LogHistoryManager();
  final _fileManager = FileLogManager();

  DiqitLogger._();

  // * --- Static Public API ---

  /// Initializes the logger with the provided [config].
  ///
  /// This must be called before any logging occurs to ensure proper setup,
  /// especially for file logging or custom printers.
  static Future<void> initialize(LoggerConfig config) async {
    await _instance._initializeInternal(config);
  }

  /// Updates the logger configuration at runtime.
  ///
  /// This allows you to modify the logger's behavior after initialization
  /// without needing to call [initialize] again. Useful for:
  /// - Enabling/disabling specific tags via [LoggerConfig.withTagsDisabled]
  /// - Changing log levels
  /// - Updating prefix messages
  ///
  /// Example:
  /// ```dart
  /// await DiqitLogger.initialize(LoggerConfig.development());
  ///
  /// // Later, disable UI logs
  /// final newConfig = LoggerConfig.development().withTagsDisabled(['UI']);
  /// await DiqitLogger.updateConfig(newConfig);
  /// ```
  static Future<void> updateConfig(LoggerConfig config) async {
    await _instance._updateConfigInternal(config);
  }

  /// Dynamically enables or disables console logging.
  ///
  /// Useful for toggling log output at runtime without re-initializing.
  static void setConsoleLogging(bool enabled) =>
      _instance._setConsoleLoggingInternal(enabled);

  /// Returns a list of recent log events kept in the memory buffer.
  ///
  /// The buffer size is limited. Useful for viewing logs inside the app
  /// (e.g. debug page).
  static List<OutputEvent> getLogHistory() =>
      _instance._historyManager.getLogHistory();

  /// Exports the recent logs as a formatted string.
  ///
  /// [lastN] - Optional: Limit to the last N lines.
  static String exportLogs({int? lastN}) =>
      _instance._historyManager.exportLogs(lastN: lastN);

  // * --- Internal Implementation Methods ---

  Future<void> _initializeInternal(LoggerConfig config) async {
    await _activeLogger?.close();

    _config = config;
    _initialized = true;

    await _fileManager.initialize(config);

    _activeLogger = _createLoggerInstance();
  }

  Future<void> _updateConfigInternal(LoggerConfig config) async {
    if (!_initialized) {
      // If not initialized yet, just call initialize
      await _initializeInternal(config);
      return;
    }

    await _activeLogger?.close();

    _config = config;

    await _fileManager.initialize(config);

    _activeLogger = _createLoggerInstance();
  }

  void _setConsoleLoggingInternal(bool enabled) {
    if (!_initialized) return;
    _config = _config.copyWith(enableConsoleLogging: enabled);
    _activeLogger = _createLoggerInstance();
  }

  /// Internal helper to construct the Logger
  Logger _createLoggerInstance({
    LogPrinter? printer,
    LogFilter? filter,
  }) {
    final outputs = <LogOutput>[];

    if (_config.enableConsoleLogging) {
      outputs.add(ConsoleOutput());
    }

    if (_config.output != null) {
      outputs.add(_config.output!);
    }

    // Always add memory output for history
    outputs.add(_historyManager.output);

    // Add file output if enabled and initialized
    if (_fileManager.output != null && _config.enableFileLogging) {
      outputs.add(_fileManager.output!);
    }

    var finalPrinter = _config.printer;

    // If an ephemeral printer is provided (e.g. via static methods),
    // wrap it to ensure Diqit features (prefix, tags) still work.
    if (printer != null) {
      finalPrinter = DiqitLogPrinter(printer, prefix: _config.prefixMessage);
    }

    return Logger(
      level: Level.all, // Filter decides
      filter: filter ?? DLogFilter(_config),
      printer: finalPrinter,
      output: MultiOutput(outputs),
    );
  }

  // * --- Core Logging Logic ---
  void _log(
    Level level,
    String message,
    LogTag tag,
    dynamic error,
    StackTrace? stackTrace, {
    dynamic data,
    DPrettyPrinter? printer,
  }) {
    if (!_initialized) {
      _config = LoggerConfig.development();
      _initialized = true;
      _activeLogger = _createLoggerInstance();
    }

    final logMsg = DLogMessage(message, tag, data);

    final targetLogger = printer != null
        ? _createLoggerInstance(printer: printer)
        : (_activeLogger!);

    targetLogger.log(
      level,
      logMsg,
      error: error,
      stackTrace: stackTrace,
    );

    if (printer != null) {
      targetLogger.close();
    }
  }

  // * --- Default Printers ---
  static DPrettyPrinter get _minimalPrinter => DPrettyPrinter.minimal();
  static DPrettyPrinter get _tracePrinter => DPrettyPrinter.trace();

  /// Logs a [Level.trace] message (Verbose).
  ///
  /// **Short Version**: Uses minimal printer.
  static void t(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.trace,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ?? _minimalPrinter,
      );

  /// Logs a [Level.trace] message (Verbose).
  ///
  /// **Full Version**: Uses trace printer.
  static void trace(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
  }) =>
      _instance._log(
        Level.trace,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ??
            (countMethod != null
                ? DPrettyPrinter.trace(
                    methodCount: countMethod, stackTraceBeginIndex: 0)
                : _tracePrinter),
      );

  /// Logs a [Level.debug] message.
  ///
  /// **Short Version**: Uses minimal printer.
  static void d(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.debug,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ?? _minimalPrinter,
      );

  /// Logs a [Level.debug] message.
  ///
  /// **Full Version**: Uses trace printer.
  static void debug(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
  }) =>
      _instance._log(
        Level.debug,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ??
            (countMethod != null
                ? DPrettyPrinter.trace(
                    methodCount: countMethod, stackTraceBeginIndex: 0)
                : _tracePrinter),
      );

  /// Logs a [Level.info] message.
  ///
  /// **Short Version**: Uses minimal printer.
  static void i(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.info,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ?? _minimalPrinter,
      );

  /// Logs a [Level.info] message.
  ///
  /// **Full Version**: Uses trace printer.
  static void info(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
  }) =>
      _instance._log(
        Level.info,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ??
            (countMethod != null
                ? DPrettyPrinter.trace(
                    methodCount: countMethod, stackTraceBeginIndex: 0)
                : _tracePrinter),
      );

  /// Logs a [Level.warning] message.
  ///
  /// **Short Version**: Uses minimal printer.
  static void w(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.warning,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ?? _minimalPrinter,
      );

  /// Logs a [Level.warning] message.
  ///
  /// **Full Version**: Uses trace printer.
  static void warning(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
  }) =>
      _instance._log(
        Level.warning,
        message,
        tag,
        null,
        null,
        data: data,
        printer: printer ??
            (countMethod != null
                ? DPrettyPrinter.trace(
                    methodCount: countMethod, stackTraceBeginIndex: 0)
                : _tracePrinter),
      );

  /// Logs a [Level.error] message.
  ///
  /// **Short Version**: Uses minimal printer.
  static void e(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.error,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: printer ?? _minimalPrinter,
      );

  /// Logs a [Level.error] message.
  ///
  /// **Full Version**: Uses trace printer.
  static void error(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
    int? countMethod,
  }) =>
      _instance._log(
        Level.error,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: printer ??
            DPrettyPrinter.trace(
              methodCount: countMethod ?? 8,
              stackTraceBeginIndex: 0,
            ),
      );

  /// Logs a [Level.fatal] message (Critical failure).
  ///
  /// **Short Version**: Uses minimal printer.
  static void ft(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.fatal,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: printer ?? _minimalPrinter,
      );

  /// Logs a [Level.fatal] message (Critical failure).
  ///
  /// **Full Version**: Uses trace printer.
  static void fatal(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
    int? countMethod,
  }) =>
      _instance._log(
        Level.fatal,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: printer ??
            (countMethod != null
                ? DPrettyPrinter.trace(
                    methodCount: countMethod, stackTraceBeginIndex: 0)
                : _tracePrinter),
      );
}
