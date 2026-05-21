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

    final hasSearchPatterns = config.searchTagPatterns != null &&
        config.searchTagPatterns!.isNotEmpty;

    if (event.message is DLogMessage) {
      final msg = event.message as DLogMessage;
      if (msg.tag == LogTag.none) {
        // When search patterns are active, untagged logs should be hidden
        return !hasSearchPatterns;
      }
      return config.isTagEnabled(msg.tag);
    }

    // Non-DLogMessage: hide when search patterns are active
    return !hasSearchPatterns;
  }
}
