import 'package:logger/logger.dart';
import 'diqit_log_message.dart';
import 'log_tag.dart';

class DiqitLogPrinter extends LogPrinter {
  final LogPrinter _realPrinter;
	final String prefix;

  DiqitLogPrinter(this._realPrinter, {this.prefix = ""});

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
    if (msg.tag == LogTag.none || msg.tag.label.isEmpty) {
      return '$prefix${msg.message}';
    }
    return '$prefix[${msg.tag.label}] :: ${msg.message}';
  }
}
