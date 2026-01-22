import 'package:diqit_logging/src/logger/diqit_log_printer.dart';
import 'package:diqit_logging/src/logger/diqit_pretty_printer.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:logger/logger.dart';

class LoggerConfig {
  Level minLogLevel;
  bool enableConsoleLogging;
  bool enableFileLogging;
  String? logDirectory;
  Set<LogTag> enabledTags;
  LogPrinter printer;
  LogOutput? output;
  String prefixMessage;
  bool allowCustomTags;

  LoggerConfig({
    this.minLogLevel = Level.debug,
    this.enableConsoleLogging = false,
    this.enableFileLogging = false,
    this.logDirectory,
    Set<LogTag>? enabledTags,
    LogPrinter? printer,
    this.output,
    this.prefixMessage = '',
    this.allowCustomTags = false,
  })  : enabledTags = enabledTags ?? Set.from(LogTag.values),
        printer = printer ??
            DiqitLogPrinter(
              DPrettyPrinter.cleanNoise(),
              prefix: prefixMessage,
            );

  factory LoggerConfig.production(
      {String? logDirectory, String prefixMessage = ''}) {
    return LoggerConfig(
      minLogLevel: Level.warning,
      enableConsoleLogging: true,
      enableFileLogging: true,
      logDirectory: logDirectory,
      enabledTags: {
        LogTag.payment,
        LogTag.order,
        LogTag.network,
        LogTag.sync,
        LogTag.database,
      },
      printer:
          DiqitLogPrinter(DPrettyPrinter.cleanNoise(), prefix: prefixMessage),
      allowCustomTags: false,
    );
  }

  factory LoggerConfig.development(
      {String? logDirectory, String prefixMessage = ''}) {
    return LoggerConfig(
      minLogLevel: Level.debug,
      enableConsoleLogging: true,
      enableFileLogging: false,
      logDirectory: logDirectory,
      enabledTags: Set.from(LogTag.values),
      printer: DiqitLogPrinter(DPrettyPrinter.trace(), prefix: prefixMessage),
      allowCustomTags: true,
    );
  }

  void enableTag(LogTag tag) => enabledTags.add(tag);
  void disableTag(LogTag tag) => enabledTags.remove(tag);
  void enableTags(Iterable<LogTag> tags) => enabledTags.addAll(tags);
  void disableTags(Iterable<LogTag> tags) => enabledTags.removeAll(tags);
  void enableAllTags() => enabledTags.addAll(LogTag.values);
  void disableAllTags() => enabledTags.clear();
  bool isTagEnabled(LogTag tag) {
    if (enabledTags.contains(tag)) return true;
    if (allowCustomTags && !LogTag.values.contains(tag)) return true;
    return false;
  }

  LoggerConfig copyWith({
    Level? minLogLevel,
    bool? enableConsoleLogging,
    bool? enableFileLogging,
    String? logDirectory,
    Set<LogTag>? enabledTags,
    LogPrinter? printer,
    LogOutput? output,
    String? prefixMessage,
    bool? allowCustomTags,
  }) {
    return LoggerConfig(
      minLogLevel: minLogLevel ?? this.minLogLevel,
      enableConsoleLogging: enableConsoleLogging ?? this.enableConsoleLogging,
      enableFileLogging: enableFileLogging ?? this.enableFileLogging,
      logDirectory: logDirectory ?? this.logDirectory,
      enabledTags: enabledTags ?? this.enabledTags,
      printer: printer ?? this.printer,
      output: output ?? this.output,
      prefixMessage: prefixMessage ?? this.prefixMessage,
      allowCustomTags: allowCustomTags ?? this.allowCustomTags,
    );
  }
}
