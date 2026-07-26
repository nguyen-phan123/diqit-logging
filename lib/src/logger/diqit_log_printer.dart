import 'package:diqit_logging/src/logger/diqit_log_message.dart';
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
    // Use toString() which includes [traceId] prefix and formatted data.
    final content = msg.toString();

    var decorated = prefix;

    if (msg.source != null && msg.source!.isNotEmpty) {
      decorated += ' [${msg.source}]';
    }

    if (msg.tag.label.isNotEmpty) {
      decorated += ' [${msg.tag.label}]';
    }

    if (msg.path != null && msg.path!.isNotEmpty) {
      decorated += ' [${msg.path}]';
    }

    final hasTagOrPath = msg.tag.label.isNotEmpty ||
        (msg.path != null && msg.path!.isNotEmpty);
    if (hasTagOrPath) {
      decorated += ' -> ';
    }

    return '$decorated$content';
  }
}
