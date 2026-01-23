import 'dart:io';
import 'package:diqit_logging/src/logger/logger_config.dart';
import 'package:logger/logger.dart';

/// Internal helper to manage file logging initialization.
class FileLogManager {
  AdvancedFileOutput? _fileOutput;

  AdvancedFileOutput? get output => _fileOutput;

  /// Initializes file logging based on config.
  /// Returns existing output if already initialized, or newly created one.
  Future<void> initialize(LoggerConfig config) async {
    // If disabled, clear existing output
    if (!config.enableFileLogging) {
      _fileOutput = null;
      return;
    }

    // If enabled but logic directory missing
    final logDir = config.logDirectory;
    if (logDir == null) {
      print('[DiqitLogger] File logging enabled but no logDirectory provided.');
      return;
    }

    // Attempt to initialize
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
}
