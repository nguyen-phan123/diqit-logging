import 'dart:io';
import 'package:logger/logger.dart';

/// Custom PrettyPrinter with preset configurations for common use cases.
///
/// Provides factory constructors for quick setup:
/// - [DPrettyPrinter.trace] - Detailed printer, for debugging complex flows.
/// - [DPrettyPrinter.minimal] - Bare text only, for production/clean output.
class DPrettyPrinter {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  /// Compact emoji set using simple symbols (1 char each, minimal width).
  @Deprecated(
      'Use DPrettyPrinter.mixedEmojis instead. Will be removed in v2.0.0.')
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

  @Deprecated(
      'Use DPrettyPrinter.minimal() or DPrettyPrinter.trace() instead. Will be removed in v2.0.0.')
  static LogPrinter compact({Map<Level, String>? levelEmojis}) =>
      DShorthandPrinter();

  @Deprecated(
      'Use DPrettyPrinter.minimal() or DPrettyPrinter.trace() instead. Will be removed in v2.0.0.')
  static LogPrinter compactSymbols() => DShorthandPrinter();

  @Deprecated(
      'Use DPrettyPrinter.minimal() or DPrettyPrinter.trace() instead. Will be removed in v2.0.0.')
  static LogPrinter compactMixed() => DShorthandPrinter();

  static LogPrinter minimal() => DShorthandPrinter(enableColors: false);

  /// Minimal printer with alignment padding.
  @Deprecated(
      'Use DPrettyPrinter.minimal() or DPrettyPrinter.trace() instead. Will be removed in v2.0.0.')
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

  static const Map<Level, String> _levelLabels = {
    Level.trace: 'T',
    Level.debug: 'D',
    Level.info: 'I',
    Level.warning: 'W',
    Level.error: 'E',
    Level.fatal: 'F',
  };

  static const String _resetColor = '\x1B[0m';
  static const String _timeColor = '\x1B[38;5;240m';
  static const String _headerColor = '\x1B[38;5;34m'; // muted green
  static const String _traceColor = '\x1B[38;5;220m'; // gold/yellow

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

    final label = _levelLabels[event.level] ?? 'I';
    final color = _levelColors[event.level] ?? '';
    final isColorEnabled = enableColors && _isColorSupported;

    final lines = messageStr.split('\n');
    final formattedLines = <String>[];

    // 19 spaces to align payload after "[HH:MM:SS.mmm] [X] "
    const indent = '                   ';
    const dimColor = '\x1B[38;5;242m'; // medium grey for data payload

    for (var i = 0; i < lines.length; i++) {
      if (i == 0) {
        if (isColorEnabled) {
          var coloredLine = lines[0];

          // Color trace IDs [#trace-123] with gold/yellow
          coloredLine = coloredLine.replaceAllMapped(
            RegExp(r'(\[#[^\]]+\])'),
            (m) => '$_traceColor${m[1]}$_resetColor',
          );

          // Color namespace headers [app/tag/path] with muted green
          coloredLine = coloredLine.replaceAllMapped(
            RegExp(r'(\[(?![#\d])[^\]]+\])'),
            (m) => '$_headerColor${m[1]}$_resetColor',
          );

          formattedLines.add(
            '$_timeColor[$timeStr]$_resetColor $color[$label]$_resetColor '
            '$coloredLine',
          );
        } else {
          formattedLines.add('[$timeStr] [$label] ${lines[i]}');
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
