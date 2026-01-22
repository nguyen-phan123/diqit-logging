import 'dart:io';
import 'package:logger/logger.dart';
import 'logger/logger.dart';

/// {@template diqit_logging}
/// My new Dart package
/// {@endtemplate}
class DiqitLogger {
  /// {@macro diqit_logging}
  DiqitLogger();
  static final DiqitLogger _instance = DiqitLogger._();

  // * --- Configuration State ---
  late DLoggerConfig _config;
  bool _initialized = false;

  // * --- internal Logger Instance ---
  Logger? _activeLogger;

  // * --- Log History & Memory ---
  final _memoryOutput = MemoryOutput(bufferSize: 1000);
  AdvancedFileOutput? _fileOutput;

  DiqitLogger._();

  // * --- Static Public API ---

  static Future<void> initialize(DLoggerConfig config) async {
    await _instance._initializeInternal(config);
  }

  static void setConsoleLogging(bool enabled) =>
      _instance._setConsoleLoggingInternal(enabled);

  static List<OutputEvent> getLogHistory() =>
      _instance._memoryOutput.buffer.toList();

  static String exportLogs({int? lastN}) =>
      _instance._exportLogsInternal(lastN: lastN);

  // * --- Internal Implementation Methods ---

  Future<void> _initializeInternal(DLoggerConfig config) async {
    _activeLogger?.close();

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
    _config.enableConsoleLogging = enabled;
    _activeLogger = _createLoggerInstance();
  }

  String _exportLogsInternal({int? lastN}) {
    List<OutputEvent> entries = _memoryOutput.buffer.toList();
    if (lastN != null && entries.length > lastN) {
      entries = entries.sublist(entries.length - lastN);
    }

    final buffer = StringBuffer();
    buffer.writeln('=== DiqitLogger Export ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 50);

    for (final event in entries) {
      for (var line in event.lines) {
        buffer.writeln(line);
      }
      buffer.writeln('-' * 20);
    }
    return buffer.toString();
  }

  /// Internal helper to construct the Logger
  Logger _createLoggerInstance({
    DPrettyPrinter? printer,
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

    return Logger(
      level: Level.all, // Để Filter quyết định
      filter: filter ?? DLogFilter(_config),
      printer: printer ?? _config.printer,
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
      if (!await directory.exists()) {
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
    DLogTag tag,
    dynamic error,
    StackTrace? stackTrace, {
    DPrettyPrinter? printer,
  }) {
    if (!_initialized) {
      _config = DLoggerConfig.development();
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

  static void t(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void trace(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void d(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void debug(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void i(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void info(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void w(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void warning(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void e(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void error(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void ft(
    String message, {
    DLogTag tag = DLogTag.none,
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

  static void fatal(
    String message, {
    DLogTag tag = DLogTag.none,
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
