import 'package:diqit_logging/src/logger/diqit_log_message.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/logger/logger_config.dart';
import 'package:logger/logger.dart';

class DLogFilter extends LogFilter {
  final LoggerConfig config;

  DLogFilter(this.config);

  @override
  bool shouldLog(LogEvent event) {
    if (event.level.value < config.minLogLevel.value) {
      return false;
    }

    if (event.message is DLogMessage) {
      final msg = event.message as DLogMessage;
      if (msg.tag == LogTag.none) return true;
      return config.isTagEnabled(msg.tag);
    }

    return true;
  }
}
