import 'dart:io';
import 'package:logger/logger.dart';

/// Custom PrettyPrinter with preset configurations for common use cases.
///
/// Provides factory constructors for quick setup:
/// - [DPrettyPrinter.trace] - Full stack trace, for debugging complex flows.
/// - [DPrettyPrinter.compact] - Emoji + message, no box, for readable logs.
/// - [DPrettyPrinter.minimal] - Bare text only, for production/clean output.
class DPrettyPrinter extends PrettyPrinter {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const int _defaultLineLength = 100;
  static const int _defaultMethodCount = 5;
  static const int _defaultStackTraceBeginIndex = 2;

  /// Whether ANSI colors are supported on this platform.
  /// iOS and Android typically don't render ANSI escape codes properly.
  static final bool isColorSupported = _detectColorSupport();

  static bool _detectColorSupport() {
    if (Platform.isIOS) return false;
    return Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isAndroid;
  }

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  DPrettyPrinter({
    super.methodCount = 8,
    super.errorMethodCount = 8,
    super.lineLength = _defaultLineLength,
    super.colors = true,
    super.printEmojis = true,
    super.printTime = false,
    super.noBoxingByDefault = false,
    super.stackTraceBeginIndex = _defaultStackTraceBeginIndex,
  });

  // ---------------------------------------------------------------------------
  // Factory Constructors
  // ---------------------------------------------------------------------------

  /// Full debugging printer with stack trace.
  ///
  /// Use when: debugging complex flows, tracing method calls.
  /// Output: Box with emoji, message, and N lines of stack trace.
  factory DPrettyPrinter.trace({
    int methodCount = _defaultMethodCount,
    int stackTraceBeginIndex = _defaultStackTraceBeginIndex,
  }) {
    return DPrettyPrinter(
      methodCount: methodCount,
      stackTraceBeginIndex: stackTraceBeginIndex,
      lineLength: _defaultLineLength,
      colors: isColorSupported,
    );
  }

  /// Compact printer: emoji + message, no box.
  ///
  /// Use when: you want readable logs without clutter but still visual.
  /// Output: Single line with emoji prefix.
  factory DPrettyPrinter.compact() {
    return DPrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: _defaultLineLength,
      colors: isColorSupported,
      noBoxingByDefault: true,
      printEmojis: true,
    );
  }

  /// Minimal printer: bare text only.
  ///
  /// Use when: production logs, file logging, or clean console output.
  /// Output: Plain text message without formatting.
  factory DPrettyPrinter.minimal() {
    return DPrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: _defaultLineLength,
      colors: isColorSupported,
      noBoxingByDefault: true,
      printEmojis: false,
    );
  }

  /// Alias for `minimal()` - backwards compatibility.
  @Deprecated('Use DPrettyPrinter.minimal() instead')
  factory DPrettyPrinter.cleanNoise() => DPrettyPrinter.minimal();
}
