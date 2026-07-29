import 'dart:io';
import 'package:logger/logger.dart';

/// Custom PrettyPrinter with preset configurations for common use cases.
///
/// Provides factory constructors for quick setup:
/// - [DPrettyPrinter.trace] - Full stack trace, for debugging complex flows.
/// - [DPrettyPrinter.minimal] - Bare text only, for production/clean output.
/// - [DPrettyPrinter.minimalAligned] - Minimal with padding for alignment.
class DPrettyPrinter {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

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
  // ---------------------------------------------------------------------------
  // Factory Constructors
  // ---------------------------------------------------------------------------

  /// Full debugging printer — same as shorthand, no boxing.
  static LogPrinter trace({
    int? methodCount,
    int? stackTraceBeginIndex,
  }) =>
      DShorthandPrinter();

  @Deprecated('Use DShorthandPrinter() directly. Will be removed in v2.0.0')
  static LogPrinter compact({Map<Level, String>? levelEmojis}) =>
      DShorthandPrinter();

  @Deprecated('Use DShorthandPrinter() directly. Will be removed in v2.0.0')
  static LogPrinter compactSymbols() => DShorthandPrinter();

  @Deprecated('Use DShorthandPrinter() directly. Will be removed in v2.0.0')
  static LogPrinter compactMixed() => DShorthandPrinter();

  static LogPrinter minimal() => DShorthandPrinter(enableColors: false);

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
    final inner = DPrettyPrinter.minimal();
    return _PaddingPrinter(inner, paddingSize: paddingSize);
  }
}

class _PaddingPrinter extends LogPrinter {
  final LogPrinter _printer;
  final int _paddingSize;

  _PaddingPrinter(this._printer, {int paddingSize = 3})
      : _paddingSize = paddingSize;

  @override
  List<String> log(LogEvent event) {
    final lines = _printer.log(event);
    if (_paddingSize <= 0) return lines;
    final padding = ' ' * _paddingSize;
    return lines.map((line) => '$padding$line').toList();
  }
}

/// A custom inline printer for shorthand logs natively supporting
/// colors and emojis without using boxing frames.
/// Implements LogPrinter directly — no PrettyPrinter base class dependency.
class DShorthandPrinter extends LogPrinter {
  final bool enableColors;

  DShorthandPrinter({this.enableColors = true});

  static const Map<Level, String> _levelColors = {
    Level.trace: '\x1B[38;5;244m', // grey
    Level.debug: '\x1B[38;5;14m', // cyan
    Level.info: '\x1B[38;5;12m', // bright blue
    Level.warning: '\x1B[38;5;208m', // orange
    Level.error: '\x1B[38;5;196m', // red
    Level.fatal: '\x1B[38;5;199m', // magenta
  };

  static const String _resetColor = '\x1B[0m';
  static const String _timeColor = '\x1B[38;5;240m';

  static const _emojis = DPrettyPrinter.mixedEmojis;
  static bool get _isColorSupported => DPrettyPrinter.isColorSupported;

  @override
  List<String> log(LogEvent event) {
    final messageStr = event.message.toString();
    final time = DateTime.now();
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    final timeStr = '$h:$m:$s.$ms';

    final emoji = _emojis[event.level] ?? '';
    final color = _levelColors[event.level] ?? '';
    final isColorEnabled = enableColors && _isColorSupported;

    final lines = messageStr.split('\n');
    final formattedLines = <String>[];

    // 17 spaces to align with the message after "[HH:MM:SS.mmm] E "
    const indent = '                 ';
    const dimColor = '\x1B[38;5;242m'; // medium grey for data payload

    for (var i = 0; i < lines.length; i++) {
      if (i == 0) {
        if (isColorEnabled) {
          formattedLines.add(
            '$emoji $_timeColor[$timeStr]$_resetColor '
            '$color${lines[i]}$_resetColor',
          );
        } else {
          formattedLines.add('$emoji [$timeStr] ${lines[i]}');
        }
      } else {
        // For Data payloads, dim the color so it doesn't clutter the console
        if (isColorEnabled) {
          formattedLines.add('$indent$dimColor${lines[i]}$_resetColor');
        } else {
          formattedLines.add('$indent${lines[i]}');
        }
      }
    }

    if (event.error != null) {
      if (isColorEnabled) {
        formattedLines.add(
          '$indent\x1B[38;5;196mError: ${event.error}$_resetColor',
        );
      } else {
        formattedLines.add('$indent Error: ${event.error}');
      }
    }

    return formattedLines;
  }
}
