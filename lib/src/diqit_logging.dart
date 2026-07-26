import 'dart:io';

import 'package:diqit_logging/src/logger/diqit_log_message.dart';
import 'package:diqit_logging/src/logger/diqit_log_printer.dart';
import 'package:diqit_logging/src/logger/diqit_pretty_printer.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/logger/logger_config.dart';
import 'package:diqit_logging/src/logger/printer_selector.dart';
import 'package:diqit_logging/src/logger/trace_id.dart';
import 'package:diqit_logging/src/logger/type_converter.dart';
import 'package:diqit_logging/src/logger/zone_trace.dart';
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
/// - **Trace Propagation**: Zone-based trace ID inheritance via [runTraced].
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

  // * --- Output State ---
  final _memoryOutput = MemoryOutput(bufferSize: 1000);
  AdvancedFileOutput? _fileOutput;

  // * --- Helpers ---
  final _typeConverterRegistry = TypeConverterRegistry();
  final _printerSelector = PrinterSelector(
    minimalPrinter: DShorthandPrinter(),
    tracePrinter: DPrettyPrinter.trace(),
  );

  DiqitLogger._() {
    ZoneTrace.onError = _onZoneTraceError;
  }

  static void _onZoneTraceError(
    Object error,
    StackTrace stackTrace,
    TraceId traceId,
  ) {
    _instance._log(
      Level.error,
      'Uncaught error in traced zone [$traceId]: $error',
      LogTag.none,
      error,
      stackTrace,
      traceId: traceId,
    );
  }

  // * --- Static Public API ---

  /// Initializes the logger with the provided [config].
  ///
  /// This must be called before any logging occurs to ensure proper setup,
  /// especially for file logging or custom printers.
  static Future<void> initialize(LoggerConfig config) async {
    await _instance._initializeInternal(config);
  }

  /// Creates a child logger with the given namespace [name].
  ///
  /// Child loggers inherit the parent's configuration (log level, tag filters,
  /// file logging) while building a slash-delimited namespace path.
  /// The namespace path appears in log output between the tag and content.
  ///
  /// Example:
  /// ```dart
  /// final kdsLogger = DiqitLogger.createChild('kds');
  /// kdsLogger.i('KDS started');  // Output: [kds] -> KDS started
  ///
  /// final gridLogger = kdsLogger.createChild('order_grid');
  /// gridLogger.i('Bump order');  // Output: [kds/order_grid] -> Bump order
  /// ```
  static DiqitChildLogger createChild(String name) {
    return DiqitChildLogger._(name);
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
      _instance._memoryOutput.buffer.toList();

  /// Exports the recent logs as a formatted string.
  ///
  /// [lastN] - Optional: Limit to the last N lines.
  static String exportLogs({int? lastN}) {
    var entries = _instance._memoryOutput.buffer.toList();
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

  // * --- Type Converter Public API ---

  /// Registers a type converter for formatting custom types in logs.
  ///
  /// Use this to register custom string representations for types you don't
  /// own (like `DateTime`, `Duration`, `Uri`) that cannot implement `Loggable`.
  ///
  /// Example:
  /// ```dart
  /// await DiqitLogger.initialize(config);
  ///
  /// // Register converters for common types
  /// DiqitLogger.registerConverter<DateTime>((dt) => dt.toIso8601String());
  /// DiqitLogger.registerConverter<Duration>((d) => '${d.inSeconds}s');
  ///
  /// // Later in code
  /// DiqitLogger.i('Event scheduled', data: DateTime.now());
  /// // Output: Event scheduled
  /// //         Data: 2026-07-26T10:30:45.123Z
  /// ```
  ///
  /// When logging with the `data` parameter, the logger tries:
  /// 1. **Loggable check** — if `data is Loggable`, call `toLoggableMap()`
  /// 2. **TypeConverter check** — if registered converter exists, use it
  /// 3. **Fallback** — call `data.toString()`
  static void registerConverter<T>(TypeConverter<T> converter) {
    _instance._typeConverterRegistry.register<T>(converter);
  }

  /// Unregister a type converter.
  ///
  /// Returns `true` if a converter was removed, `false` otherwise.
  static bool unregisterConverter<T>() {
    return _instance._typeConverterRegistry.unregister<T>();
  }

  /// Returns the type converter registry instance for advanced usage.
  ///
  /// Most users should use [registerConverter] instead.
  static TypeConverterRegistry get typeConverterRegistry =>
      _instance._typeConverterRegistry;

  // * --- Trace Propagation Public API ---

  /// Returns the current active trace ID from the Zone, or null.
  static TraceId? get currentTraceId => ZoneTrace.currentTrace();

  /// Returns the current zone context (entity metadata), or null.
  static Map<String, dynamic>? get currentContext => ZoneTrace.currentContext();

  /// Wraps an async callback in a zone with automatic trace propagation.
  ///
  /// All logs within [callback] will automatically include [traceId].
  /// Nested traces append to the parent trace stack.
  ///
  /// Optional [context] carries structured entity metadata (e.g. order_id,
  /// user_id) that is inherited by logs within this zone. When null, inherits
  /// the parent zone's context.
  ///
  /// Example:
  /// ```dart
  /// await DiqitLogger.runTraced(
  ///   TraceId.manual('user-login'),
  ///   () async {
  ///     DiqitLogger.i('Starting login'); // Auto-tagged with 'user-login'
  ///     await apiClient.login();
  ///     DiqitLogger.i('Login complete'); // Auto-tagged with 'user-login'
  ///   },
  /// );
  /// ```
  static Future<T> runTraced<T>(
    TraceId traceId,
    Future<T> Function() callback, {
    Map<String, dynamic>? context,
  }) {
    return ZoneTrace.runTraced(traceId, callback, context: context);
  }

  /// Wraps a sync callback in a zone with automatic trace propagation.
  ///
  /// Synchronous version of [runTraced].
  ///
  /// Example:
  /// ```dart
  /// DiqitLogger.runTracedSync(
  ///   TraceId.auto(prefix: 'compute'),
  ///   () {
  ///     DiqitLogger.d('Processing data');
  ///     // ... synchronous work ...
  ///   },
  /// );
  /// ```
  static T runTracedSync<T>(
    TraceId traceId,
    T Function() callback, {
    Map<String, dynamic>? context,
  }) {
    return ZoneTrace.runTracedSync(traceId, callback, context: context);
  }

  /// Returns log history events specifically matching [traceId].
  static List<OutputEvent> getLogHistoryForTrace(String traceId) {
    final searchTag = '[$traceId]';
    return _instance._memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();
  }

  /// Exports formatted log entries matching [traceId].
  static String exportLogsForTrace(String traceId, {int? lastN}) {
    final searchTag = '[$traceId]';
    var entries = _instance._memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();

    if (lastN != null && entries.length > lastN) {
      entries = entries.sublist(entries.length - lastN);
    }

    final buffer = StringBuffer();
    buffer.writeln('=== DiqitLogger Trace Export [$traceId] ===');
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

  /// Returns log history events matching a context key-value pair.
  ///
  /// Provides entity-based filtering independent of trace ID. For example,
  /// find all logs related to a specific order regardless of which
  /// operation (bump, cancel, update) produced them.
  ///
  /// Example:
  /// ```dart
  /// final logs = DiqitLogger.getLogHistoryByContext('order_id', 'ORD-001');
  /// ```
  static List<OutputEvent> getLogHistoryByContext(
    String key,
    dynamic value,
  ) {
    final searchPattern = value is String
        ? '"$key":"$value"'
        : '"$key":$value';
    return _instance._memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchPattern));
    }).toList();
  }

  /// Returns log history events matching a namespace [path].
  ///
  /// Provides subsystem-based filtering using the path set by
  /// [createChild]. For example, isolate all logs from the KDS order grid.
  ///
  /// Example:
  /// ```dart
  /// final gridLogs = DiqitLogger.getLogHistoryByPath('kds/order_grid');
  /// ```
  static List<OutputEvent> getLogHistoryByPath(String path) {
    final searchTag = '[$path]';
    return _instance._memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();
  }

  // * --- Internal Implementation Methods ---

  Future<void> _initializeInternal(LoggerConfig config) async {
    await _activeLogger?.close();

    _config = config;
    _initialized = true;

    await _initializeFileOutput(config);

    _activeLogger = _createLoggerInstance();

    // Wire cross-app source identity
    ZoneTrace.sourceAppName = config.appName;

    // Register default type converters
    _registerDefaultConverters();
  }

  /// Registers commonly-used type converters by default.
  ///
  /// Includes DateTime, Duration, and Uri. Users can override these
  /// by calling `registerConverter<T>()` after initialization.
  void _registerDefaultConverters() {
    _typeConverterRegistry.register<DateTime>(
      (dt) => dt.toIso8601String(),
    );
    _typeConverterRegistry.register<Duration>(
      (d) => '${d.inMilliseconds}ms',
    );
    _typeConverterRegistry.register<Uri>(
      (uri) => uri.toString(),
    );
  }

  Future<void> _updateConfigInternal(LoggerConfig config) async {
    if (!_initialized) {
      await _initializeInternal(config);
      return;
    }

    await _activeLogger?.close();

    _config = config;

    await _initializeFileOutput(config);

    _activeLogger = _createLoggerInstance();

    // Wire cross-app source identity
    ZoneTrace.sourceAppName = config.appName;
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
      level: Level.all, // Filter decides
      filter: filter ?? _InlineFilter(_config),
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
    TraceId? traceId,
    Map<String, dynamic>? context,
    String? path,
  }) {
    if (!_initialized) {
      _config = LoggerConfig.development();
      _initialized = true;
      _activeLogger = _createLoggerInstance();
    }

    // Resolve trace ID: explicit parameter > zone context > null
    final resolvedTraceId = traceId ?? _resolveZoneTrace();

    // Resolve context: explicit parameter > zone context > null
    final resolvedContext = context ?? ZoneTrace.currentContext();

    final logMsg = DLogMessage(
      message,
      tag,
      data,
      resolvedTraceId,
      _typeConverterRegistry,
      resolvedContext,
      path,
      ZoneTrace.sourceAppName,
    );

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

  /// Resolves trace ID from Zone context, formatting nested traces as a chain.
  ///
  /// Returns null if no trace is active. When multiple traces are nested,
  /// returns a composite trace formatted as "outer > inner".
  TraceId? _resolveZoneTrace() {
    final stack = ZoneTrace.currentTraceList();
    if (stack.isEmpty) return null;
    if (stack.length == 1) return stack.first;

    // Multiple traces: create composite
    return _CompositeTraceId(stack);
  }

  /// Initializes file logging output based on config.
  Future<void> _initializeFileOutput(LoggerConfig config) async {
    _fileOutput = null;
    if (!config.enableFileLogging) return;

    final logDir = config.logDirectory;
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

  /// Logs a [Level.trace] message (Verbose).
  ///
  /// **Short Version**: Uses minimal printer.
  static void t(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.trace,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: true,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.trace,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: false,
          countMethod: countMethod,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
      );

  /// Logs a [Level.trace] message specifically for flow execution tracing.
  /// Uses a custom 'function' tag to support filtering.
  static void flow({
    Map<String, dynamic>? args,
    DPrettyPrinter? printer,
    LogTag? tag,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) {
    final stackTrace = StackTrace.current.toString().split('\n');
    // Index 0: StackTrace.current
    // Index 1: DiqitLogger.flow
    // Index 2: The function calling flow() (current function)
    // Index 3: The function calling the current function

    final currentFunc =
        _extractFunctionName(stackTrace.length > 2 ? stackTrace[2] : '');
    final callerFunc =
        _extractFunctionName(stackTrace.length > 3 ? stackTrace[3] : '');

    final flowPath =
        callerFunc.isNotEmpty ? '$callerFunc -> $currentFunc' : currentFunc;
    var finalMessage = '[$flowPath]';

    if (args != null && args.isNotEmpty) {
      finalMessage += '\nParams: $args';
    }

    _instance._log(
      Level.debug,
      finalMessage,
      tag ?? LogTag.custom('function'),
      null,
      null,
      printer: _instance._printerSelector.select(
        isShorthand: true,
        customPrinter: printer,
      ),
      traceId: traceId,
      context: context,
    );
  }

  static String _extractFunctionName(String stackTraceLine) {
    if (stackTraceLine.isEmpty) return '';
    final regex = RegExp(r'#\d+\s+([^\s]+)');
    final match = regex.firstMatch(stackTraceLine);
    if (match != null && match.groupCount >= 1) {
      final name = match.group(1) ?? '';
      return name.replaceAll(RegExp(r'\.<anonymous closure>'), '');
    }
    return '';
  }

  /// Logs a [Level.debug] message.
  ///
  /// **Short Version**: Uses minimal printer.
  static void d(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.debug,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: true,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.debug,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: false,
          countMethod: countMethod,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
      );

  /// Logs a [Level.info] message.
  ///
  /// **Short Version**: Uses minimal printer.
  static void i(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.info,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: true,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.info,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: false,
          countMethod: countMethod,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
      );

  /// Logs a [Level.warning] message.
  ///
  /// **Short Version**: Uses minimal printer.
  static void w(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.warning,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: true,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.warning,
        message,
        tag,
        null,
        null,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: false,
          countMethod: countMethod,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.error,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: true,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.error,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: false,
          countMethod: countMethod,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.fatal,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: true,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
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
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      _instance._log(
        Level.fatal,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: _instance._printerSelector.select(
          isShorthand: false,
          countMethod: countMethod,
          customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
      );
}

/// {@template diqit_child_logger}
/// A child logger with a namespace path, created via [DiqitLogger.createChild].
///
/// Child loggers delegate all logging to the root singleton while prepending
/// their namespace path to every log message. They support further nesting
/// via their own [createChild] method.
///
/// Example:
/// ```dart
/// final kdsLogger = DiqitLogger.createChild('kds');
/// kdsLogger.i('KDS started');  // Output: [kds] -> KDS started
///
/// final gridLogger = kdsLogger.createChild('order_grid');
/// gridLogger.d('Bump order');  // Output: [kds/order_grid] -> Bump order
/// ```
/// {@endtemplate}
class DiqitChildLogger {
  final String _path;

  const DiqitChildLogger._(this._path);

  /// Returns the current namespace path (e.g., `kds/order_grid`).
  String get path => _path;

  /// Creates a nested child logger with [name] appended to this path.
  DiqitChildLogger createChild(String name) {
    return DiqitChildLogger._(_path.isEmpty ? name : '$_path/$name');
  }

  /// Logs a [Level.trace] message (Verbose).
  void t(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.trace, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: true, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.trace] message (Verbose, full version).
  void trace(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.trace, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: false, countMethod: countMethod, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.debug] message.
  void d(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.debug, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: true, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.debug] message (full version).
  void debug(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.debug, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: false, countMethod: countMethod, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.info] message.
  void i(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.info, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: true, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.info] message (full version).
  void info(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.info, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: false, countMethod: countMethod, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.warning] message.
  void w(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.warning, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: true, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.warning] message (full version).
  void warning(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    DPrettyPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.warning, message, tag, null, null,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: false, countMethod: countMethod, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.error] message.
  void e(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.error, message, tag, error, stackTrace,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: true, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.error] message (full version).
  void error(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.error, message, tag, error, stackTrace,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: false, countMethod: countMethod, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.fatal] message (Critical failure).
  void ft(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.fatal, message, tag, error, stackTrace,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: true, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a [Level.fatal] message (Critical failure, full version).
  void fatal(String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    DPrettyPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger._instance._log(
        Level.fatal, message, tag, error, stackTrace,
        data: data,
        printer: DiqitLogger._instance._printerSelector.select(
          isShorthand: false, countMethod: countMethod, customPrinter: printer,
        ),
        traceId: traceId,
        context: context,
        path: _path,
      );

  /// Logs a flow execution trace.
  void flow({
    Map<String, dynamic>? args,
    DPrettyPrinter? printer,
    LogTag? tag,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      DiqitLogger.flow(
        args: args,
        printer: printer,
        tag: tag,
        traceId: traceId,
        context: context,
      );
}

/// Inline filter that delegates tag filtering logic to LoggerConfig.
class _InlineFilter extends LogFilter {
  final LoggerConfig config;

  _InlineFilter(this.config);

  @override
  bool shouldLog(LogEvent event) {
    if (event.level.value < config.minLogLevel.value) {
      return false;
    }

    final hasSearchPatterns = config.searchTagPatterns != null &&
        config.searchTagPatterns!.isNotEmpty;

    if (event.message is DLogMessage) {
      final msg = event.message as DLogMessage;
      if (msg.tag == LogTag.none) {
        // When search patterns are active, untagged logs should be hidden
        return !hasSearchPatterns;
      }
      return config.isTagEnabled(msg.tag);
    }

    // Non-DLogMessage: hide when search patterns are active
    return !hasSearchPatterns;
  }
}

/// Internal composite trace ID for formatting nested traces.
///
/// When traces are nested (e.g., outer > inner), this formats them
/// as a single joined string.
class _CompositeTraceId implements TraceId {
  final List<TraceId> _stack;

  _CompositeTraceId(this._stack);

  @override
  String toString() => _stack.map((t) => t.toString()).join(' > ');

  @override
  TraceId withSuffix(String suffix) => this;
}
