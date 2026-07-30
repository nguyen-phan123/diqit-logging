import 'dart:io';

import 'package:diqit_logging/src/logger/diqit_log_message.dart';
import 'package:diqit_logging/src/logger/diqit_pretty_printer.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/logger/logger_config.dart';
import 'package:diqit_logging/src/logger/network_output.dart';
import 'package:diqit_logging/src/logger/safe_console_output.dart';
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
///   full methods (e.g., `trace`, `debug`) use a detailed trace printer.
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
  DiqitLogger([this._path = '']);

  /// Creates a scoped logger instance with the given namespace [path].
  factory DiqitLogger.scoped(String path) => DiqitLogger(path);

  /// Shared in-memory buffer across all logger instances.
  static MemoryOutput _globalBuffer = MemoryOutput(bufferSize: 1000);

  /// The default root logger instance for static convenience API.
  static final DiqitLogger root = DiqitLogger._();

  // * --- Configuration State ---
  late LoggerConfig _config;
  bool _initialized = false;
  final String _path;

  // * --- internal Logger Instance ---
  Logger? _activeLogger;

  // * --- Output State ---
  AdvancedFileOutput? _fileOutput;
  NetworkOutput? _networkOutput;

  /// The active network output, if network logging is enabled.
  NetworkOutput? get networkOutput => _networkOutput;

  // * --- Helpers ---
  final _typeConverterRegistry = TypeConverterRegistry();
  final _minimalPrinter = DShorthandPrinter();
  final _tracePrinter = DPrettyPrinter.trace();

  DiqitLogger._() : _path = '' {
    ZoneTrace.onError = _onZoneTraceError;
  }

  static void _onZoneTraceError(
    Object error,
    StackTrace stackTrace,
    TraceId traceId,
  ) {
    root._log(
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
    await root._initializeInternal(config);
  }

  /// Creates a child logger with the given namespace [name].
  ///
  /// Child loggers inherit the parent's configuration while building a
  /// slash-delimited namespace path.
  DiqitLogger createChild(String name) {
    return DiqitLogger._child(_path.isEmpty ? name : '$_path/$name');
  }

  DiqitLogger._child(this._path);

  /// Unified log method — instance version.
  ///
  /// Logs through this instance with its own config, printers, and converters.
  /// The path from this instance's `_path` is automatically injected.
  void log(
    Level level,
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    TraceId? traceId,
    Map<String, dynamic>? context,
    bool shorthand = true,
    int? countMethod,
  }) {
    final printer = countMethod != null
        ? DPrettyPrinter.trace(
            methodCount: countMethod,
            stackTraceBeginIndex: 0,
          )
        : shorthand
            ? _minimalPrinter
            : _tracePrinter;
    _log(
      level,
      message,
      tag,
      error,
      stackTrace,
      data: data,
      printer: printer,
      traceId: traceId,
      context: context,
    );
  }

  // * --- Static Log API (backward compat) ---

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
    await root._updateConfigInternal(config);
  }

  /// Dynamically enables or disables console logging.
  ///
  /// Useful for toggling log output at runtime without re-initializing.
  @Deprecated(
    'Use LoggerConfig.copyWith(enableConsoleLogging:) + updateConfig(). '
    'Will be removed in v2.0.0',
  )
  static void setConsoleLogging(bool enabled) =>
      root._setConsoleLoggingInternal(enabled);

  /// Returns a list of recent log events kept in the memory buffer.
  ///
  /// The buffer size is limited. Useful for viewing logs inside the app
  /// (e.g. debug page).
  @Deprecated('Use NetworkOutput for live streaming. Will be removed in v2.0.0')
  static List<OutputEvent> getLogHistory() => _globalBuffer.buffer.toList();

  /// Exports the recent logs as a formatted string.
  ///
  /// [lastN] - Optional: Limit to the last N lines.
  @Deprecated('Use NetworkOutput for live streaming. Will be removed in v2.0.0')
  static String exportLogs({int? lastN}) {
    var entries = _globalBuffer.buffer.toList();
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

  /// Clears the in-memory log history buffer.
  ///
  /// Discards all buffered log events and starts fresh. Affects all connected
  /// NetworkOutput clients — the next buffer dump will show an empty history.
  ///
  /// Example:
  /// ```dart
  /// DiqitLogger.clearLogHistory();
  /// ```
  @Deprecated('Use NetworkOutput !clear command. Will be removed in v2.0.0')
  static void clearLogHistory() {
    root._clearLogHistoryInternal();
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
    root._typeConverterRegistry.register<T>(converter);
  }

  /// Unregister a type converter.
  ///
  /// Returns `true` if a converter was removed, `false` otherwise.
  @Deprecated('Use registerConverter() to override. Will be removed in v2.0.0')
  static bool unregisterConverter<T>() {
    return root._typeConverterRegistry.unregister<T>();
  }

  /// Returns the type converter registry instance for advanced usage.
  ///
  /// Most users should use [registerConverter] instead.
  static TypeConverterRegistry get typeConverterRegistry =>
      root._typeConverterRegistry;

  // * --- Per-Instance Converter API ---

  /// Register a type converter on this logger instance only.
  ///
  /// Scoped to this instance — does NOT affect root or other instances.
  /// Use the static [registerConverter] for root-wide converters.
  @Deprecated(
    'Use static registerConverter() instead. '
    'Will be removed in v2.0.0',
  )
  void addConverter<T>(TypeConverter<T> converter) {
    _typeConverterRegistry.register<T>(converter);
  }

  /// Unregister a type converter on this logger instance.
  @Deprecated(
    'Use static registerConverter() to override. '
    'Will be removed in v2.0.0',
  )
  bool removeConverter<T>() {
    return _typeConverterRegistry.unregister<T>();
  }

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
  @Deprecated('Use NetworkOutput for live streaming. Will be removed in v2.0.0')
  static List<OutputEvent> getLogHistoryForTrace(String traceId) {
    final searchTag = '[$traceId]';
    return _globalBuffer.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();
  }

  /// Exports formatted log entries matching [traceId].
  @Deprecated('Use NetworkOutput for live streaming. Will be removed in v2.0.0')
  static String exportLogsForTrace(String traceId, {int? lastN}) {
    final searchTag = '[$traceId]';
    var entries = _globalBuffer.buffer.where((event) {
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
  @Deprecated('Use NetworkOutput for live streaming. Will be removed in v2.0.0')
  static List<OutputEvent> getLogHistoryByContext(
    String key,
    dynamic value,
  ) {
    final searchPattern = value is String ? '"$key":"$value"' : '"$key":$value';
    return _globalBuffer.buffer.where((event) {
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
  @Deprecated('Use NetworkOutput for live streaming. Will be removed in v2.0.0')
  static List<OutputEvent> getLogHistoryByPath(String path) {
    final searchTag = '[$path]';
    return _globalBuffer.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();
  }

  // * --- Internal Implementation Methods ---

  Future<void> _initializeInternal(LoggerConfig config) async {
    await _activeLogger?.close();

    _config = config;
    _initialized = true;

    await _initializeFileOutput(config);

    await _initializeNetworkOutput(config);

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

    await _initializeNetworkOutput(config);

    _activeLogger = _createLoggerInstance();

    // Wire cross-app source identity
    ZoneTrace.sourceAppName = config.appName;
  }

  void _setConsoleLoggingInternal(bool enabled) {
    if (!_initialized) return;
    _config = _config.copyWith(enableConsoleLogging: enabled);
    _activeLogger = _createLoggerInstance();
  }

  void _clearLogHistoryInternal() {
    _globalBuffer = MemoryOutput(bufferSize: 1000);
    _activeLogger = _createLoggerInstance();
  }

  /// Internal helper to construct the Logger
  Logger _createLoggerInstance({
    LogPrinter? printer,
    LogFilter? filter,
  }) {
    final outputs = <LogOutput>[];

    if (_config.enableConsoleLogging) {
      outputs.add(SafeConsoleOutput());
    }

    if (_config.output != null) {
      outputs.add(_config.output!);
    }

    // Always add memory output for history
    outputs.add(_globalBuffer);

    // Add file output if enabled and initialized
    if (_fileOutput != null && _config.enableFileLogging) {
      outputs.add(_fileOutput!);
    }

    // Add network output if enabled and initialized
    if (_networkOutput != null && _config.enableNetworkLogging) {
      outputs.add(_networkOutput!);
    }

    var finalPrinter = printer ?? _config.printer;

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
    LogPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
    String? path,
  }) {
    if (this != root) {
      root._log(
        level,
        message,
        tag,
        error,
        stackTrace,
        data: data,
        printer: printer,
        traceId: traceId,
        context: context,
        path: path ?? (_path.isEmpty ? null : _path),
      );
      return;
    }

    if (!_initialized) {
      _config = LoggerConfig.development();
      _initialized = true;
      _activeLogger = _createLoggerInstance();
      _registerDefaultConverters();
    }

    // Resolve trace ID: explicit parameter > zone context > null
    final resolvedTraceId = traceId ?? _resolveZoneTrace();

    // Resolve context: explicit parameter > zone context > null
    final resolvedContext = context ?? ZoneTrace.currentContext();

    final logMsg = DLogMessage(
      message: message,
      tag: tag,
      data: data,
      traceId: resolvedTraceId,
      typeConverterRegistry: _typeConverterRegistry,
      context: resolvedContext,
      path: path ?? (_path.isEmpty ? null : _path),
      source: ZoneTrace.sourceAppName,
    );

    final targetLogger = printer != null
        ? _createLoggerInstance(printer: printer)
        : _activeLogger!;

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

  /// Initializes network output (WebSocket server) based on config.
  Future<void> _initializeNetworkOutput(LoggerConfig config) async {
    await _networkOutput?.stop();
    _networkOutput = null;

    if (!config.enableNetworkLogging) return;

    try {
      _networkOutput = NetworkOutput(port: config.networkPort);
      await _networkOutput!.start(
        bufferGetter: () => _globalBuffer.buffer.toList(),
        onClear: _clearLogHistoryInternal,
      );
      print(
        '[DiqitLogger] Log stream available at ws://0.0.0.0:'
        '${config.networkPort}',
      );
    } catch (e) {
      print('[DiqitLogger] Failed to start network output: $e');
      _networkOutput = null;
    }
  }

  /// Canonical static shortcut for trace-level logging.
  static void t(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.trace, message,
          data: data, tag: tag, traceId: traceId, context: context);

  @Deprecated('Use DiqitLogger.t() instead. Will be removed in v2.0.0')
  static void trace(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.trace, message,
          data: data,
          tag: tag,
          traceId: traceId,
          context: context,
          shorthand: false,
          countMethod: countMethod);

  /// Canonical static shortcut for debug-level logging.
  static void d(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.debug, message,
          data: data, tag: tag, traceId: traceId, context: context);

  @Deprecated('Use DiqitLogger.d() instead. Will be removed in v2.0.0')
  static void debug(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.debug, message,
          data: data,
          tag: tag,
          traceId: traceId,
          context: context,
          shorthand: false,
          countMethod: countMethod);

  /// Canonical static shortcut for info-level logging.
  static void i(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.info, message,
          data: data, tag: tag, traceId: traceId, context: context);

  @Deprecated('Use DiqitLogger.i() instead. Will be removed in v2.0.0')
  static void info(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.info, message,
          data: data,
          tag: tag,
          traceId: traceId,
          context: context,
          shorthand: false,
          countMethod: countMethod);

  /// Canonical static shortcut for warning-level logging.
  static void w(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.warning, message,
          data: data, tag: tag, traceId: traceId, context: context);

  @Deprecated('Use DiqitLogger.w() instead. Will be removed in v2.0.0')
  static void warning(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    LogPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.warning, message,
          data: data,
          tag: tag,
          traceId: traceId,
          context: context,
          shorthand: false,
          countMethod: countMethod);

  /// Canonical static shortcut for error-level logging.
  static void e(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    LogPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.error, message,
          data: data,
          tag: tag,
          error: error,
          stackTrace: stackTrace,
          traceId: traceId,
          context: context);

  @Deprecated('Use DiqitLogger.e() instead. Will be removed in v2.0.0')
  static void error(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    LogPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.error, message,
          data: data,
          tag: tag,
          error: error,
          stackTrace: stackTrace,
          traceId: traceId,
          context: context,
          shorthand: false,
          countMethod: countMethod);

  /// Canonical static shortcut for fatal-level logging.
  static void ft(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    LogPrinter? printer,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.fatal, message,
          data: data,
          tag: tag,
          error: error,
          stackTrace: stackTrace,
          traceId: traceId,
          context: context);

  @Deprecated('Use DiqitLogger.ft() instead. Will be removed in v2.0.0')
  static void fatal(
    String message, {
    dynamic data,
    LogTag tag = LogTag.none,
    dynamic error,
    StackTrace? stackTrace,
    LogPrinter? printer,
    int? countMethod,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) =>
      root.log(Level.fatal, message,
          data: data,
          tag: tag,
          error: error,
          stackTrace: stackTrace,
          traceId: traceId,
          context: context,
          shorthand: false,
          countMethod: countMethod);

  /// Logs a flow execution trace (uses debug level, function tag).
  @Deprecated(
    'Use runTraced() + DiqitLogger.d() for automatic trace propagation. '
    'Will be removed in v2.0.0',
  )
  static void flow({
    Map<String, dynamic>? args,
    DPrettyPrinter? printer,
    LogTag? tag,
    TraceId? traceId,
    Map<String, dynamic>? context,
  }) {
    final stackTrace = StackTrace.current.toString().split('\n');
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
    root.log(Level.debug, finalMessage,
        tag: tag ?? LogTag.custom('function'),
        traceId: traceId,
        context: context);
  }

  @Deprecated(
    'Internal helper for flow(). Will be removed in v2.0.0',
  )
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
}

/// Inline filter that delegates tag filtering logic to LoggerConfig.
class _InlineFilter extends LogFilter {
  final LoggerConfig config;

  _InlineFilter(this.config);

  @override
  bool shouldLog(LogEvent event) {
    if (event.level.value < config.minLogLevel.value) return false;

    final hasSearchPatterns = config.searchTagPatterns != null &&
        config.searchTagPatterns!.isNotEmpty;

    if (event.message is DLogMessage) {
      final msg = event.message as DLogMessage;
      if (msg.tag == LogTag.none) return !hasSearchPatterns;
      if (!config.isTagEnabled(msg.tag)) return false;
    } else {
      if (hasSearchPatterns) return false;
    }

    final hasTracePatterns =
        config.traceIdPatterns != null && config.traceIdPatterns!.isNotEmpty;
    if (!hasTracePatterns) return true;

    if (event.message is DLogMessage) {
      final msg = event.message as DLogMessage;
      final traceId = msg.traceId;
      if (traceId == null) return false;
      final traceStr = traceId.toString();
      return config.traceIdPatterns!.any(traceStr.contains);
    }

    return false;
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
