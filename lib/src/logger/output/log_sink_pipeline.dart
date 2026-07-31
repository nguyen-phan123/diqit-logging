import 'dart:io';

import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/logger/logger_config.dart';
import 'package:diqit_logging/src/logger/message/diqit_log_message.dart';
import 'package:diqit_logging/src/logger/output/network_output.dart';
import 'package:diqit_logging/src/logger/output/safe_console_output.dart';
import 'package:logger/logger.dart';

/// {@template log_sink_pipeline}
/// An internal deep module managing the lifecycle, configuration updates,
/// and dispatching for all log output sinks (Console, File, Network WebSocket, Memory Buffer).
/// {@endtemplate}
class LogSinkPipeline {
  /// {@macro log_sink_pipeline}
  LogSinkPipeline({MemoryOutput? globalBuffer})
      : _globalBuffer = globalBuffer ?? MemoryOutput(bufferSize: 1000);

  MemoryOutput _globalBuffer;
  AdvancedFileOutput? _fileOutput;
  NetworkOutput? _networkOutput;

  /// In-memory rolling log history buffer.
  MemoryOutput get buffer => _globalBuffer;

  /// Active network WebSocket output, if enabled.
  NetworkOutput? get networkOutput => _networkOutput;

  /// Initializes all configured sinks based on [config].
  Future<void> initialize(
    LoggerConfig config, {
    required void Function() onClearHistory,
  }) async {
    await _initializeFileOutput(config);
    await _initializeNetworkOutput(config, onClearHistory: onClearHistory);
  }

  /// Updates existing sinks when [config] changes.
  Future<void> updateConfig(
    LoggerConfig config, {
    required void Function() onClearHistory,
  }) async {
    await _initializeFileOutput(config);
    await _initializeNetworkOutput(config, onClearHistory: onClearHistory);
  }

  /// Clears in-memory buffer.
  void clearHistory() {
    _globalBuffer = MemoryOutput(bufferSize: 1000);
  }

  /// Creates a [Logger] instance with the active sink pipeline.
  Logger createLogger(
    LoggerConfig config, {
    LogPrinter? printer,
    LogFilter? filter,
  }) {
    final outputs = <LogOutput>[];

    if (config.enableConsoleLogging) {
      outputs.add(SafeConsoleOutput());
    }

    if (config.output != null) {
      outputs.add(config.output!);
    }

    // Memory buffer for history inspection & dumps
    outputs.add(_globalBuffer);

    // File output if enabled
    if (_fileOutput != null && config.enableFileLogging) {
      outputs.add(_fileOutput!);
    }

    // Network output if enabled
    if (_networkOutput != null && config.enableNetworkLogging) {
      outputs.add(_networkOutput!);
    }

    return Logger(
      level: Level.all,
      filter: filter ?? _InlineSinkFilter(config),
      printer: printer ?? config.printer,
      output: MultiOutput(outputs),
    );
  }

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

  Future<void> _initializeNetworkOutput(
    LoggerConfig config, {
    required void Function() onClearHistory,
  }) async {
    await _networkOutput?.stop();
    _networkOutput = null;

    if (!config.enableNetworkLogging) return;

    try {
      _networkOutput = NetworkOutput(port: config.networkPort);
      await _networkOutput!.start(
        bufferGetter: () => _globalBuffer.buffer.toList(),
        onClear: onClearHistory,
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

  /// Closes all managed output sinks and servers.
  Future<void> close() async {
    await _networkOutput?.stop();
    _networkOutput = null;
    _fileOutput = null;
  }
}

class _InlineSinkFilter extends LogFilter {
  final LoggerConfig config;

  _InlineSinkFilter(this.config);

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
