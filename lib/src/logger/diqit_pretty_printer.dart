import 'dart:io';
import 'package:diqit_logging/src/logger/aligned_pretty_printer.dart';
import 'package:logger/logger.dart';

/// Custom PrettyPrinter with preset configurations for common use cases.
///
/// Provides factory constructors for quick setup:
/// - [DPrettyPrinter.trace] - Full stack trace, for debugging complex flows.
/// - [DPrettyPrinter.compact] - Emoji + message, no box, for readable logs.
/// - [DPrettyPrinter.compactSymbols] - Compact with symbol-based emojis
///   (smaller).
/// - [DPrettyPrinter.compactMixed] - Compact with mixed emojis (balanced).
/// - [DPrettyPrinter.minimal] - Bare text only, for production/clean output.
/// - [DPrettyPrinter.minimalAligned] - Minimal with padding for alignment.
class DPrettyPrinter extends PrettyPrinter {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const int _defaultLineLength = 100;
  static const int _defaultMethodCount = 5;
  static const int _defaultStackTraceBeginIndex = 2;

  /// Compact emoji set using simple symbols (1 char each, minimal width).
  ///
  /// Best for: Terminal alignment, minimal visual noise.
  /// - trace: · (middle dot)
  /// - debug: • (bullet)
  /// - info: ℹ (information symbol)
  /// - warning: ⚠ (warning sign)
  /// - error: ✖ (heavy multiplication X)
  /// - fatal: ☠ (skull and crossbones)
  static const Map<Level, String> symbolsEmojis = {
    Level.trace: '·',
    Level.debug: '•',
    Level.info: 'ℹ',
    Level.warning: '⚠',
    Level.error: '✖',
    Level.fatal: '☠',
  };

  /// Mixed emoji set balancing visual appeal and size.
  ///
  /// Best for: Readable logs with clear visual distinction.
  /// - trace: ▫ (white square)
  /// - debug: ▪ (black square)
  /// - info: ℹ (information symbol)
  /// - warning: ⚡ (lightning)
  /// - error: ❗ (exclamation)
  /// - fatal: 💀 (skull)
  static const Map<Level, String> mixedEmojis = {
    Level.trace: '▫',
    Level.debug: '▪',
    Level.info: 'ℹ',
    Level.warning: '⚡',
    Level.error: '❗',
    Level.fatal: '💀',
  };

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
    super.dateTimeFormat = DateTimeFormat.onlyTime,
    super.noBoxingByDefault = false,
    super.stackTraceBeginIndex = _defaultStackTraceBeginIndex,
    super.levelEmojis,
  });

  // ---------------------------------------------------------------------------
  // Factory Constructors
  // ---------------------------------------------------------------------------

  /// Full debugging printer with stack trace.
  ///
  /// Use when: debugging complex flows, tracing method calls.
  /// Output: Box with emoji, message, and N lines of stack trace.
  ///
  /// Example:
  /// ```dart
  /// final logger = Logger(printer: DPrettyPrinter.trace());
  /// ```
  factory DPrettyPrinter.trace({
    int methodCount = _defaultMethodCount,
    int stackTraceBeginIndex = _defaultStackTraceBeginIndex,
    Map<Level, String>? levelEmojis,
  }) {
    return DPrettyPrinter(
      methodCount: methodCount,
      stackTraceBeginIndex: stackTraceBeginIndex,
      lineLength: _defaultLineLength,
      colors: isColorSupported,
      levelEmojis: levelEmojis,
    );
  }

  /// Compact printer: emoji + message, no box.
  ///
  /// Use when: you want readable logs without clutter but still visual.
  /// Output: Single line with emoji prefix (uses default logger emojis).
  ///
  /// Example:
  /// ```dart
  /// final logger = Logger(printer: DPrettyPrinter.compact());
  /// // Output: 💡 Info message
  /// ```
  factory DPrettyPrinter.compact({Map<Level, String>? levelEmojis}) {
    return DPrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: _defaultLineLength,
      colors: isColorSupported,
      noBoxingByDefault: true,
      printEmojis: true,
      levelEmojis: levelEmojis,
    );
  }

  /// Compact printer with symbol-based emojis (minimal width).
  ///
  /// Use when: you want minimal visual noise and perfect terminal alignment.
  /// Output: Single line with 1-char symbol prefix (·•ℹ⚠✖☠).
  ///
  /// Example:
  /// ```dart
  /// • Debug message
  /// ℹ Info message
  /// ⚠ Warning message
  /// ```
  factory DPrettyPrinter.compactSymbols() {
    return DPrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: _defaultLineLength,
      colors: isColorSupported,
      noBoxingByDefault: true,
      printEmojis: true,
      levelEmojis: symbolsEmojis,
    );
  }

  /// Compact printer with mixed emojis (balanced visual appeal & size).
  ///
  /// Use when: you want clear visual distinction with compact size.
  /// Output: Single line with small emoji prefix (▫▪ℹ⚡❗💀).
  ///
  /// Example:
  /// ```dart
  /// ▪ Debug message
  /// ℹ Info message
  /// ⚡ Warning message
  /// ```
  factory DPrettyPrinter.compactMixed() {
    return DPrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: _defaultLineLength,
      colors: isColorSupported,
      noBoxingByDefault: true,
      printEmojis: true,
      levelEmojis: mixedEmojis,
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

  /// Minimal printer with alignment padding.
  ///
  /// Use when: mixing minimal logs with compact logs (with emojis).
  /// Output: Plain text with leading spaces to align with emoji logs.
  ///
  /// Example:
  /// ```dart
  /// // Compact log
  /// 💡 User logged in
  /// // MinimalAligned log
  ///    Session started  // 3 spaces padding
  /// ```
  static LogPrinter minimalAligned({int paddingSize = 3}) {
    return AlignedPrettyPrinter(
      DPrettyPrinter.minimal(),
      paddingSize: paddingSize,
    );
  }

  /// Alias for `minimal()` - backwards compatibility.
  @Deprecated('Use DPrettyPrinter.minimal() instead')
  factory DPrettyPrinter.cleanNoise() => DPrettyPrinter.minimal();
}
