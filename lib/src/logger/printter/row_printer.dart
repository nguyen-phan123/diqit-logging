import 'dart:io';

import 'package:diqit_logging/src/logger/log_element.dart';
import 'package:diqit_logging/src/logger/message/diqit_log_message.dart';
import 'package:logger/logger.dart';

class RowPrinter extends LogPrinter {
  final List<LogElement> _children;
  final List<LogElement> _tail;
  final bool _enableColors;

  static int _seqCounter = 0;

  /// Whether ANSI colors are supported on this platform.
  static final bool isColorSupported = _detectColorSupport();

  static bool _detectColorSupport() {
    if (Platform.isIOS) return false;
    return Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isAndroid;
  }

  RowPrinter({
    List<LogElement> children = const [
      LogNumElement(),
      LogLevelElement(),
      LogTimeElement(),
      LogPathElement(),
      LogFunctionElement(),
      LogTraceIdElement(),
      LogMessageElement(),
    ],
    List<LogElement> tail = const [],
    bool enableColors = true,
  })  : _children = children,
        _tail = tail,
        _enableColors = enableColors;

  @override
  List<String> log(LogEvent event) {
    _seqCounter++;
    final msg = event.message;
    if (msg is! DLogMessage) return [msg.toString()];

    final isColorEnabled = _enableColors && isColorSupported;
    final time = DateTime.now();
    final ctx = LogRenderContext(
      message: msg,
      level: event.level,
      timestamp: time,
      sequenceNum: _seqCounter,
      isColorEnabled: isColorEnabled,
      stackTrace: event.stackTrace,
    );

    final prefixParts = <String>[];
    for (var i = 0; i < _children.length - 1; i++) {
      final text = _children[i].build(ctx);
      if (text.isNotEmpty) prefixParts.add(text);
    }
    for (final element in _tail) {
      final text = element.build(ctx);
      if (text.isNotEmpty) prefixParts.add(text);
    }

    final messageText = _children.last.build(ctx);

    final prefixStr = prefixParts.join(' ');
    final firstLine =
        prefixParts.isEmpty ? messageText : '$prefixStr $messageText';

    final result = <String>[firstLine];

    const indent = '  ';

    if (msg.data != null) {
      final formatted = msg.formattedData;
      if (formatted != null) {
        for (final line in formatted.split('\n').where((l) => l.isNotEmpty)) {
          if (isColorEnabled) {
            result.add('$indent${LogAnsiColor.dim}$line${LogAnsiColor.reset}');
          } else {
            result.add('$indent$line');
          }
        }
      }
    }

    if (event.error != null) {
      if (isColorEnabled) {
        result.add(
            '$indent${LogAnsiColor.error}Error: ${event.error}${LogAnsiColor.reset}');
      } else {
        result.add('$indent Error: ${event.error}');
      }
    }

    if (event.stackTrace != null) {
      for (final line in event.stackTrace.toString().split('\n')) {
        if (line.isNotEmpty) {
          if (isColorEnabled) {
            result.add('$indent${LogAnsiColor.dim}$line${LogAnsiColor.reset}');
          } else {
            result.add('$indent$line');
          }
        }
      }
    }

    return result;
  }
}
