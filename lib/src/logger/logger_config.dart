import 'package:diqit_logging/src/logger/diqit_log_printer.dart';
import 'package:diqit_logging/src/logger/diqit_pretty_printer.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:logger/logger.dart';

/// Configuration for DiqitLogger.
///
/// Use factory constructors for common setups:
/// - [LoggerConfig.development] - Verbose logs, all tags enabled.
/// - [LoggerConfig.production] - Warnings only, critical tags, file logging.
class LoggerConfig {
  final Level minLogLevel;
  final bool enableConsoleLogging;
  final bool enableFileLogging;
  final String? logDirectory;
  final Set<LogTag> enabledTags;
  final LogPrinter printer;
  final LogOutput? output;
  final String prefixMessage;
  final bool allowCustomTags;

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
        printer = printer ?? _defaultPrinter(prefixMessage);

  // ---------------------------------------------------------------------------
  // Factory Constructors
  // ---------------------------------------------------------------------------

  /// Development config: verbose, all tags, trace printer.
  factory LoggerConfig.development({
    String? logDirectory,
    String prefixMessage = '',
  }) {
    return LoggerConfig(
      minLogLevel: Level.debug,
      enableConsoleLogging: true,
      enableFileLogging: false,
      logDirectory: logDirectory,
      enabledTags: Set.from(LogTag.values),
      printer: _tracePrinter(prefixMessage),
      prefixMessage: prefixMessage,
      allowCustomTags: true,
    );
  }

  /// Production config: warnings+, critical tags only, file logging enabled.
  factory LoggerConfig.production({
    String? logDirectory,
    String prefixMessage = '',
  }) {
    return LoggerConfig(
      minLogLevel: Level.warning,
      enableConsoleLogging: true,
      enableFileLogging: true,
      logDirectory: logDirectory,
      enabledTags: _productionTags,
      printer: _defaultPrinter(prefixMessage),
      prefixMessage: prefixMessage,
      allowCustomTags: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Tag Utilities
  // ---------------------------------------------------------------------------

  /// Checks if a tag should be logged.
  bool isTagEnabled(LogTag tag) {
    if (enabledTags.contains(tag)) return true;
    if (allowCustomTags && !LogTag.values.contains(tag)) return true;
    return false;
  }

  /// Finds a [LogTag] by its label string (case-insensitive).
  /// Returns `null` if not found in predefined tags.
  /// If [allowCustom] is true, returns a custom tag when not found.
  static LogTag? findTagByLabel(String label, {bool allowCustom = false}) {
    final normalized = label.toUpperCase();
    for (final tag in LogTag.values) {
      if (tag.label.toUpperCase() == normalized) return tag;
    }
    return allowCustom ? LogTag.custom(label) : null;
  }

  /// Returns a new config with the specified tag enabled (by label).
  /// If the label doesn't match a predefined tag, creates a custom tag.
  LoggerConfig withTagEnabled(String label) {
    final tag = findTagByLabel(label, allowCustom: true)!;
    final newTags = Set<LogTag>.from(enabledTags)..add(tag);
    return copyWith(enabledTags: newTags);
  }

  /// Returns a new config with the specified tag disabled (by label).
  LoggerConfig withTagDisabled(String label) {
    final tag = findTagByLabel(label, allowCustom: true)!;
    final newTags = Set<LogTag>.from(enabledTags)..remove(tag);
    return copyWith(enabledTags: newTags);
  }

  /// Returns a new config with multiple tags enabled (by labels).
  LoggerConfig withTagsEnabled(Iterable<String> labels) {
    final newTags = Set<LogTag>.from(enabledTags);
    for (final label in labels) {
      final tag = findTagByLabel(label, allowCustom: true)!;
      newTags.add(tag);
    }
    return copyWith(enabledTags: newTags);
  }

  /// Returns a new config with multiple tags disabled (by labels).
  LoggerConfig withTagsDisabled(Iterable<String> labels) {
    final newTags = Set<LogTag>.from(enabledTags);
    for (final label in labels) {
      final tag = findTagByLabel(label, allowCustom: true)!;
      newTags.remove(tag);
    }
    return copyWith(enabledTags: newTags);
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------

  /// Creates a copy with updated fields.
  ///
  /// Note: If [prefixMessage] changes and [printer] is not provided,
  /// a new printer with the updated prefix will be created.
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
    final newPrefix = prefixMessage ?? this.prefixMessage;
    final prefixChanged =
        prefixMessage != null && prefixMessage != this.prefixMessage;

    return LoggerConfig(
      minLogLevel: minLogLevel ?? this.minLogLevel,
      enableConsoleLogging: enableConsoleLogging ?? this.enableConsoleLogging,
      enableFileLogging: enableFileLogging ?? this.enableFileLogging,
      logDirectory: logDirectory ?? this.logDirectory,
      enabledTags: enabledTags ?? this.enabledTags,
      printer: printer ??
          (prefixChanged ? _defaultPrinter(newPrefix) : this.printer),
      output: output ?? this.output,
      prefixMessage: newPrefix,
      allowCustomTags: allowCustomTags ?? this.allowCustomTags,
    );
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  static LogPrinter _defaultPrinter(String prefix) => DiqitLogPrinter(
        DPrettyPrinter.cleanNoise(),
        prefix: prefix,
      );

  static LogPrinter _tracePrinter(String prefix) => DiqitLogPrinter(
        DPrettyPrinter.trace(),
        prefix: prefix,
      );

  static final Set<LogTag> _productionTags = {
    LogTag.payment,
    LogTag.order,
    LogTag.network,
    LogTag.sync,
    LogTag.database,
  };
}
