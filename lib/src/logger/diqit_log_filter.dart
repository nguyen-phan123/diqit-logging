import 'package:logger/logger.dart';

import 'diqit_log_message.dart';
import 'log_tag.dart';
import 'logger_config.dart';

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
