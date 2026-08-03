import 'dart:convert';

import 'package:diqit_logging/src/logger/message/diqit_log_message.dart';
import 'package:logger/logger.dart';

abstract class LogAnsiColor {
  static const reset = '\x1B[0m';
  static const dim = '\x1B[38;5;242m';
  static const error = '\x1B[38;5;196m';

  static const Map<Level, String> levelColors = {
    Level.trace: '\x1B[38;5;244m',
    Level.debug: '\x1B[38;5;14m',
    Level.info: '\x1B[38;5;12m',
    Level.warning: '\x1B[38;5;208m',
    Level.error: '\x1B[38;5;196m',
    Level.fatal: '\x1B[38;5;199m',
  };

  static String forLevel(Level level) => levelColors[level] ?? '';
}

class LogRenderContext {
  final DLogMessage message;
  final Level level;
  final DateTime timestamp;
  final int sequenceNum;
  final bool isColorEnabled;
  final String? member;
  final StackTrace? stackTrace;

  const LogRenderContext({
    required this.message,
    required this.level,
    required this.timestamp,
    required this.sequenceNum,
    required this.isColorEnabled,
    this.member,
    this.stackTrace,
  });
}

// ignore: one_member_abstracts
abstract class LogElement {
  const LogElement();

  String build(LogRenderContext ctx);
}

class LogNumElement extends LogElement {
  const LogNumElement();

  @override
  String build(LogRenderContext ctx) {
    final text = '(${ctx.sequenceNum})';
    if (!ctx.isColorEnabled) return text;
    final color = LogAnsiColor.forLevel(ctx.level);
    return '$color$text${LogAnsiColor.reset}';
  }
}

class LogLevelElement extends LogElement {
  const LogLevelElement();

  static const _chars = <Level, String>{
    Level.trace: '[t]',
    Level.debug: '[d]',
    Level.info: '[i]',
    Level.warning: '[w]',
    Level.error: '[e]',
    Level.fatal: '[f]',
  };

  @override
  String build(LogRenderContext ctx) {
    final char = _chars[ctx.level] ?? '[?]';
    if (!ctx.isColorEnabled) return char;
    final color = LogAnsiColor.forLevel(ctx.level);
    return '$color$char${LogAnsiColor.reset}';
  }
}

class LogTimeElement extends LogElement {
  const LogTimeElement();

  @override
  String build(LogRenderContext ctx) {
    final t = ctx.timestamp;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    final text = '$h:$m:$s.$ms';
    if (!ctx.isColorEnabled) return text;
    final color = LogAnsiColor.forLevel(ctx.level);
    return '$color$text${LogAnsiColor.reset}';
  }
}

class LogPathElement extends LogElement {
  const LogPathElement();

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
    if (!ctx.isColorEnabled) return text;
    final color = LogAnsiColor.forLevel(ctx.level);
    return '$color$text${LogAnsiColor.reset}';
  }
}

class LogTraceIdElement extends LogElement {
  const LogTraceIdElement();

  @override
  String build(LogRenderContext ctx) {
    final traceId = ctx.message.traceId;
    if (traceId == null) return '';
    final text = '{$traceId}';
    if (!ctx.isColorEnabled) return text;
    final color = LogAnsiColor.forLevel(ctx.level);
    return '$color$text${LogAnsiColor.reset}';
  }
}

class LogMessageElement extends LogElement {
  const LogMessageElement();

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
    final color = LogAnsiColor.forLevel(ctx.level);
    return '$color$text${LogAnsiColor.reset}';
  }
}

class LogFunctionElement extends LogElement {
  final String? fallbackMember;

  const LogFunctionElement({this.fallbackMember});

  @override
  String build(LogRenderContext ctx) {
    final rawMember = ctx.message.member ??
        ctx.member ??
        _extractMember(ctx.stackTrace) ??
        fallbackMember;

    if (rawMember == null || rawMember.isEmpty) return '';

    final memberText = rawMember.startsWith('{') && rawMember.endsWith('}')
        ? rawMember
        : '{$rawMember}';

    if (!ctx.isColorEnabled) return memberText;
    final color = LogAnsiColor.forLevel(ctx.level);
    return '$color$memberText${LogAnsiColor.reset}';
  }

  static String? _extractMember(StackTrace? stackTrace) {
    if (stackTrace == null) return null;
    final lines = stackTrace.toString().split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = RegExp(r'#\d+\s+([^\s()]+)').firstMatch(trimmed);
      if (match != null) {
        final symbol = match.group(1);
        if (symbol != null &&
            !symbol.contains('RowPrinter') &&
            !symbol.contains('DiqitLogger') &&
            !symbol.contains('Logger') &&
            !symbol.contains('LogFunctionElement') &&
            !symbol.contains('LogElement')) {
          return symbol;
        }
      }
    }
    return null;
  }
}
