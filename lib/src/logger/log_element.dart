import 'dart:convert';

import 'package:diqit_logging/src/logger/diqit_log_message.dart';
import 'package:logger/logger.dart';

class LogRenderContext {
  final DLogMessage message;
  final Level level;
  final DateTime timestamp;
  final int sequenceNum;
  final bool isColorEnabled;

  const LogRenderContext({
    required this.message,
    required this.level,
    required this.timestamp,
    required this.sequenceNum,
    required this.isColorEnabled,
  });
}

abstract class LogElement {
  const LogElement();

  String build(LogRenderContext ctx);
}

class LogNumElement extends LogElement {
  const LogNumElement();

  static const _dimColor = '\x1B[38;5;242m';
  static const _resetColor = '\x1B[0m';

  @override
  String build(LogRenderContext ctx) {
    final text = '#${ctx.sequenceNum}';
    return ctx.isColorEnabled ? '$_dimColor$text$_resetColor' : text;
  }
}

class LogLevelElement extends LogElement {
  const LogLevelElement();

  static const _chars = <Level, String>{
    Level.trace: 'T',
    Level.debug: 'D',
    Level.info: 'I',
    Level.warning: 'W',
    Level.error: 'E',
    Level.fatal: 'F',
  };

  static const _colors = <Level, String>{
    Level.trace: '\x1B[38;5;244m',
    Level.debug: '\x1B[38;5;14m',
    Level.info: '\x1B[38;5;12m',
    Level.warning: '\x1B[38;5;208m',
    Level.error: '\x1B[38;5;196m',
    Level.fatal: '\x1B[38;5;199m',
  };

  static const _resetColor = '\x1B[0m';

  @override
  String build(LogRenderContext ctx) {
    final char = _chars[ctx.level] ?? '?';
    if (!ctx.isColorEnabled) return char;
    final color = _colors[ctx.level] ?? '';
    return '$color$char$_resetColor';
  }
}

class LogTimeElement extends LogElement {
  const LogTimeElement();

  static const _dimColor = '\x1B[38;5;240m';
  static const _resetColor = '\x1B[0m';

  @override
  String build(LogRenderContext ctx) {
    final t = ctx.timestamp;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final text = '$h:$m:$s';
    return ctx.isColorEnabled ? '$_dimColor$text$_resetColor' : text;
  }
}

class LogPathElement extends LogElement {
  const LogPathElement();

  static const _dimColor = '\x1B[38;5;242m';
  static const _resetColor = '\x1B[0m';

  @override
  String build(LogRenderContext ctx) {
    final msg = ctx.message;
    final parts = <String>[];

    final source = msg.source;
    if (source != null && source.isNotEmpty) {
      final clean = source.startsWith('[') && source.endsWith(']')
          ? source.substring(1, source.length - 1)
          : source;
      parts.add(clean);
    }

    if (msg.tag.label.isNotEmpty) {
      parts.add(msg.tag.label);
    }

    if (msg.path != null && msg.path!.isNotEmpty) {
      parts.add(msg.path!);
    }

    if (parts.isEmpty) return '';

    final text = '[${parts.join('/')}]';
    return ctx.isColorEnabled ? '$_dimColor$text$_resetColor' : text;
  }
}

class LogTraceIdElement extends LogElement {
  const LogTraceIdElement();

  static const _dimColor = '\x1B[38;5;242m';
  static const _resetColor = '\x1B[0m';

  @override
  String build(LogRenderContext ctx) {
    final traceId = ctx.message.traceId;
    if (traceId == null) return '';
    final text = '{$traceId}';
    return ctx.isColorEnabled ? '$_dimColor$text$_resetColor' : text;
  }
}

class LogMessageElement extends LogElement {
  const LogMessageElement();

  static const _colors = <Level, String>{
    Level.trace: '\x1B[38;5;244m',
    Level.debug: '\x1B[38;5;14m',
    Level.info: '\x1B[38;5;12m',
    Level.warning: '\x1B[38;5;208m',
    Level.error: '\x1B[38;5;196m',
    Level.fatal: '\x1B[38;5;199m',
  };

  static const _resetColor = '\x1B[0m';

  @override
  String build(LogRenderContext ctx) {
    final msg = ctx.message;
    final buf = StringBuffer();

    buf.write(msg.message);

    if (msg.context != null && msg.context!.isNotEmpty) {
      buf.write(' ');
      try {
        const encoder = JsonEncoder();
        buf.write(encoder.convert(msg.context));
      } catch (_) {
        buf.write(msg.context.toString());
      }
    }

    final text = buf.toString();
    if (!ctx.isColorEnabled) return text;
    final color = _colors[ctx.level] ?? '';
    return '$color$text$_resetColor';
  }
}
