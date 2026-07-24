import 'package:diqit_logging/src/logger/diqit_log_message.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/trace/trace_zone.dart';
import 'package:logger/logger.dart';

class DiqitLogPrinter extends LogPrinter {
  final LogPrinter _realPrinter;
  final String prefix;

  DiqitLogPrinter(this._realPrinter, {this.prefix = ''});

  @override
  List<String> log(LogEvent event) {
    if (event.message is DLogMessage) {
      final msg = event.message as DLogMessage;
      // Decorate message: [TAG] :: content
      final decoratedMessage = _formatMessage(msg);

      // Create a shadow event with decorated string
      final decoratedEvent = LogEvent(
        event.level,
        decoratedMessage,
        error: event.error,
        stackTrace: event.stackTrace,
      );

      return _realPrinter.log(decoratedEvent);
    }

    return _realPrinter.log(event);
  }

  String _formatMessage(DLogMessage msg) {
    // Use toString() to include data (pretty-formatted)
    final content = msg.toString();
    final traceId = TraceZone.currentTraceId;
    final traceStr =
        (traceId != null && traceId.isNotEmpty) ? '[trace:$traceId] ' : '';

    if (msg.tag == LogTag.none || msg.tag.label.isEmpty) {
      return '$prefix$traceStr$content';
    }
    return '$prefix [${msg.tag.label}] $traceStr:: $content';
  }
}
