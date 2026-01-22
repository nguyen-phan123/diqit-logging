import 'dart:io';
import 'package:diqit_logging/src/logger/logger.dart';
import 'package:logger/logger.dart';

/// {@template diqit_logging}
/// A singleton logger wrapper offering a unified logging interface.
///
/// Features:
/// - **Singleton**: Global access via static methods.
/// - **Tag Support**: Categorize logs with [LogTag].
/// - **Dual Printers**: Short methods (e.g., [t], [d]) use a clean printer;
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

  // * --- Log History & Memory ---
  final _memoryOutput = MemoryOutput(bufferSize: 1000);
  AdvancedFileOutput? _fileOutput;

  DiqitLogger._();

  // * --- Static Public API ---

  /// Initializes the logger with the provided [config].
  ///
  /// This must be called before any logging occurs to ensure proper setup,
  /// especially for file logging or custom printers.
  static Future<void> initialize(LoggerConfig config) async {
    await _instance._initializeInternal(config);
  }

  /// Dynamically enables or disables console logging.
  ///
  /// Useful for toggling log output at runtime without re-initializing.
  static void setConsoleLogging(bool enabled) =>
      _instance._setConsoleLoggingInternal(enabled);

  /// Returns a list of recent log events kept in the memory buffer.
  ///
  /// The buffer size is limited (default 1000). Useful for viewing logs inside the app (e.g. debug page).
  static List<OutputEvent> getLogHistory() =>
      _instance._memoryOutput.buffer.toList();

  /// Exports the recent logs as a formatted string.
  ///
  /// [lastN] - Optional: Limit to the last N lines.
  static String exportLogs({int? lastN}) =>
      _instance._exportLogsInternal(lastN: lastN);

  // * --- Internal Implementation Methods ---

  Future<void> _initializeInternal(LoggerConfig config) async {
    await _activeLogger?.close();

    _config = config;
    _initialized = true;

    if (config.enableFileLogging) {
      await _initFileLogging();
    } else {
      _fileOutput = null;
    }

    _activeLogger = _createLoggerInstance();
  }

  void _setConsoleLoggingInternal(bool enabled) {
    if (!_initialized) return;
    _config = _config.copyWith(enableConsoleLogging: enabled);
    _activeLogger = _createLoggerInstance();
  }

  String _exportLogsInternal({int? lastN}) {
    var entries = _memoryOutput.buffer.toList();
    if (lastN != null && entries.length > lastN) {
      entries = entries.sublist(entries.length - lastN);
    }

    final buffer = StringBuffer();
    buffer.writeln('=== DiqitLogger Export ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 50);

    for (final event in entries) {
      for (final line in event.lines) {
        buffer.writeln(line);
      }
      buffer.writeln('-' * 20);
    }
    return buffer.toString();
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
    outputs.add(_memoryOutput);

    // Add file output if enabled and initialized
    if (_fileOutput != null && _config.enableFileLogging) {
      outputs.add(_fileOutput!);
    }

    var finalPrinter = _config.printer;

    // If an ephemeral printer is provided (e.g. via static methods),
    // wrap it to ensure Diqit features (prefix, tags) still work.
    if (printer != null) {
      finalPrinter = DiqitLogPrinter(printer, prefix: _config.prefixMessage);
    }

    return Logger(
      level: Level.all, // Để Filter quyết định
      filter: filter ?? DLogFilter(_config),
      printer: finalPrinter,
      output: MultiOutput(outputs),
    );
  }

  /// Initialize file logging
  Future<void> _initFileLogging() async {
    final logDir = _config.logDirectory;
    if (logDir == null) {
      print('[DiqitLogger] File logging enabled but no logDirectory provided.');
      return;
    }

    try {
      final directory = Directory(logDir);
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      final separator = Platform.pathSeparator;
      final cleanPath =
          logDir.endsWith(separator) ? logDir : '$logDir$separator';

      _fileOutput = AdvancedFileOutput(
        path: '${cleanPath}diqit_logs.log',
        maxFileSizeKB: 1024,
      );

      print('File logging initialized at ${cleanPath}diqit_logs.log');
    } catch (e) {
      print('Failed to initialize file logging: $e');
      _fileOutput = null;
    }
  }

  // * --- Core Logging Logic ---
  void _log(
    Level level,
    String message,
    LogTag tag,
    dynamic error,
    StackTrace? stackTrace, {
    DPrettyPrinter? printer,
  }) {
    if (!_initialized) {
      _config = LoggerConfig.development();
      _initialized = true;
      _activeLogger = _createLoggerInstance();
    }

    final logMsg = DLogMessage(message, tag);

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

  /// Logs a [Level.trace] message (Verbose).
  ///
  /// **Short Version**: Uses Reduced-Noise printer for cleaner output.
  static void t(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.trace,
        message,
        tag,
        null,
        null,
        printer: printer ?? DPrettyPrinter.cleanNoise(),
      );

  /// Logs a [Level.trace] message (Verbose).
  ///
  /// **Full Version**: Uses Trace printer with method stack trace info.
  static void trace(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.trace,
        message,
        tag,
        null,
        null,
        printer: printer ??
            DPrettyPrinter.trace(
              methodCount: 8,
              stackTraceBeginIndex: 2,
            ),
      );

  /// Logs a [Level.debug] message.
  ///
  /// **Short Version**: Uses Reduced-Noise printer for cleaner output.
  static void d(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.debug,
        message,
        tag,
        null,
        null,
        printer: printer ?? DPrettyPrinter.cleanNoise(),
      );

  /// Logs a [Level.debug] message.
  ///
  /// **Full Version**: Uses printer with basic trace info.
  static void debug(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.debug,
        message,
        tag,
        null,
        null,
        printer: printer ?? DPrettyPrinter.trace(),
      );

  /// Logs a [Level.info] message.
  ///
  /// **Short Version**: Uses Reduced-Noise printer for cleaner output.
  static void i(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.info,
        message,
        tag,
        null,
        null,
        printer: printer ?? DPrettyPrinter.cleanNoise(),
      );

  /// Logs a [Level.info] message.
  ///
  /// **Full Version**: Uses printer with basic trace info.
  static void info(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.info,
        message,
        tag,
        null,
        null,
        printer: printer ?? DPrettyPrinter.trace(),
      );

  /// Logs a [Level.warning] message.
  ///
  /// **Short Version**: Uses Reduced-Noise printer for cleaner output.
  static void w(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.warning,
        message,
        tag,
        null,
        null,
        printer: printer ?? DPrettyPrinter.cleanNoise(),
      );

  /// Logs a [Level.warning] message.
  ///
  /// **Full Version**: Uses printer with basic trace info.
  static void warning(
    String message, {
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
  }) =>
      _instance._log(
        Level.warning,
        message,
        tag,
        null,
        null,
        printer: printer ?? DPrettyPrinter.trace(),
      );

  /// Logs a [Level.error] message.
  ///
  /// **Short Version**: Uses Reduced-Noise printer.
  static void e(
    String message, {
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
        printer: printer ?? DPrettyPrinter.cleanNoise(),
      );

  /// Logs a [Level.error] message.
  ///
  /// **Full Version**: Uses Trace printer with deep stack trace (method count 8).
  static void error(
    String message, {
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
        printer: printer ??
            DPrettyPrinter.trace(
              methodCount: 8,
              stackTraceBeginIndex: 2,
            ),
      );

  /// Logs a [Level.fatal] message (Critical failure).
  ///
  /// **Short Version**: Uses Reduced-Noise printer.
  static void ft(
    String message, {
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
        printer: printer ?? DPrettyPrinter.cleanNoise(),
      );

  /// Logs a [Level.fatal] message (Critical failure).
  ///
  /// **Full Version**: Uses Trace printer with deep stack trace (method count 8).
  static void fatal(
    String message, {
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
        printer: printer ??
            DPrettyPrinter.trace(
              methodCount: 8,
              stackTraceBeginIndex: 2,
            ),
      );
}
