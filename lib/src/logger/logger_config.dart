import 'package:logger/logger.dart';

import 'diqit_log_printer.dart';
import 'diqit_pretty_printer.dart';
import 'log_tag.dart';

class DLoggerConfig {
  Level minLogLevel;
  bool enableConsoleLogging;
  bool enableFileLogging;
  String? logDirectory;
  Set<DLogTag> enabledTags;
  LogPrinter printer;
  LogOutput? output;
  String prefixMessage;
  bool allowCustomTags;

  DLoggerConfig({
    this.minLogLevel = Level.debug,
    this.enableConsoleLogging = false,
    this.enableFileLogging = false,
    this.logDirectory,
    Set<DLogTag>? enabledTags,
    LogPrinter? printer,
    this.output,
    this.prefixMessage = "",
    this.allowCustomTags = false,
  })  : enabledTags = enabledTags ?? Set.from(DLogTag.values),
        printer = printer ??
            DiqitLogPrinter(
              DPrettyPrinter.cleanNoise(),
              prefix: prefixMessage,
            );

  factory DLoggerConfig.production(
      {String? logDirectory, String prefixMessage = ""}) {
    return DLoggerConfig(
      minLogLevel: Level.warning,
      enableConsoleLogging: true,
      enableFileLogging: true,
      logDirectory: logDirectory,
      enabledTags: {
        DLogTag.payment,
        DLogTag.order,
        DLogTag.network,
        DLogTag.sync,
        DLogTag.database,
      },
      printer:
          DiqitLogPrinter(DPrettyPrinter.cleanNoise(), prefix: prefixMessage),
      allowCustomTags: false,
    );
  }

  factory DLoggerConfig.development(
      {String? logDirectory, String prefixMessage = ""}) {
    return DLoggerConfig(
      minLogLevel: Level.debug,
      enableConsoleLogging: true,
      enableFileLogging: false,
      logDirectory: logDirectory,
      enabledTags: Set.from(DLogTag.values),
      printer: DiqitLogPrinter(DPrettyPrinter.trace(), prefix: prefixMessage),
      allowCustomTags: true,
    );
  }

  void enableTag(DLogTag tag) => enabledTags.add(tag);
  void disableTag(DLogTag tag) => enabledTags.remove(tag);
  void enableTags(Iterable<DLogTag> tags) => enabledTags.addAll(tags);
  void disableTags(Iterable<DLogTag> tags) => enabledTags.removeAll(tags);
  void enableAllTags() => enabledTags.addAll(DLogTag.values);
  void disableAllTags() => enabledTags.clear();
  bool isTagEnabled(DLogTag tag) {
    if (enabledTags.contains(tag)) return true;
    if (allowCustomTags && !DLogTag.values.contains(tag)) return true;
    return false;
  }

  DLoggerConfig copyWith({
    Level? minLogLevel,
    bool? enableConsoleLogging,
    bool? enableFileLogging,
    String? logDirectory,
    Set<DLogTag>? enabledTags,
    LogPrinter? printer,
    LogOutput? output,
    String? prefixMessage,
    bool? allowCustomTags,
  }) {
    return DLoggerConfig(
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
