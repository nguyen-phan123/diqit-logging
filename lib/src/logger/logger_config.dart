import 'package:diqit_logging/src/logger/diqit_pretty_printer.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:logger/logger.dart';

typedef LogTagFilter = bool Function(LogTag tag);
typedef LogLevel = Level;

/// Configuration for DiqitLogger.
///
/// Use factory constructors for common setups:
/// - [LoggerConfig.development] - Verbose logs, all tags enabled.
/// - [LoggerConfig.production] - Warnings only, critical tags, file logging.
class LoggerConfig {
  final Level minLogLevel;
  final bool enableConsoleLogging;
  final bool enableFileLogging;
  final bool enableNetworkLogging;
  final int networkPort;
  final String? logDirectory;
  final Set<LogTag> enabledTags;
  final Set<LogTag> disabledTags;
  final LogPrinter printer;
  final LogOutput? output;
  final String prefixMessage;
  final bool allowCustomTags;
  final List<String>? searchTagPatterns;
  final String? appName;

  LoggerConfig({
    this.minLogLevel = Level.debug,
    this.enableConsoleLogging = false,
    this.enableFileLogging = false,
    this.enableNetworkLogging = false,
    this.networkPort = 9229,
    this.logDirectory,
    Set<LogTag>? enabledTags,
    Set<LogTag>? disabledTags,
    LogPrinter? printer,
    this.output,
    this.prefixMessage = '',
    this.allowCustomTags = false,
    this.searchTagPatterns,
    this.appName,
  })  : enabledTags = enabledTags ?? Set.from(LogTag.values),
        disabledTags = disabledTags ?? {},
        printer = printer ?? _defaultPrinter(prefixMessage);

  // ---------------------------------------------------------------------------
  // Factory Constructors
  // ---------------------------------------------------------------------------

  /// Development config: verbose, all tags, trace printer.
  factory LoggerConfig.development({
    String? logDirectory,
    String prefixMessage = '',
    LogLevel? minLogLevel,
    List<String>? searchTagPatterns,
    String? appName,
  }) {
    const envTag = String.fromEnvironment('LOG_TAGS', defaultValue: '');

    final resolvedPatterns = searchTagPatterns ??
        (envTag.isNotEmpty
            ? envTag.split(',').map((e) => e.trim()).toList()
            : null);

    return LoggerConfig(
      minLogLevel: minLogLevel ?? LogLevel.debug,
      enableConsoleLogging: true,
      enableFileLogging: false,
      logDirectory: logDirectory,
      enabledTags: Set.from(LogTag.values),
      printer: _tracePrinter(prefixMessage),
      prefixMessage: prefixMessage,
      allowCustomTags: true,
      searchTagPatterns: resolvedPatterns,
      appName: appName,
    );
  }

  /// Production config: warnings+, critical tags only, file logging enabled.
  factory LoggerConfig.production({
    String? logDirectory,
    String prefixMessage = '',
    List<String>? searchTagPatterns,
    String? appName,
  }) {
    return LoggerConfig(
      minLogLevel: LogLevel.warning,
      enableConsoleLogging: true,
      enableFileLogging: true,
      logDirectory: logDirectory,
      enabledTags: _productionTags,
      printer: _defaultPrinter(prefixMessage),
      prefixMessage: prefixMessage,
      allowCustomTags: false,
      searchTagPatterns: searchTagPatterns,
      appName: appName,
    );
  }

  // ---------------------------------------------------------------------------
  // Tag Utilities
  // ---------------------------------------------------------------------------

  /// Checks if a tag should be logged.
  bool isTagEnabled(LogTag tag) {
    if (searchTagPatterns != null && searchTagPatterns!.isNotEmpty) {
      final label = tag.label.toLowerCase();
      return searchTagPatterns!.any((p) => label == p.toLowerCase());
    }

    // Always deny if explicitly disabled
    if (disabledTags.contains(tag)) return false;

    // Allow if explicitly enabled
    if (enabledTags.contains(tag)) return true;

    // For custom tags: allow if allowCustomTags is true
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
    final newDisabled = Set<LogTag>.from(disabledTags)..remove(tag);
    return copyWith(enabledTags: newTags, disabledTags: newDisabled);
  }

  /// Returns a new config with the specified tag disabled (by label).
  LoggerConfig withTagDisabled(String label) {
    final tag = findTagByLabel(label, allowCustom: true)!;
    final newTags = Set<LogTag>.from(enabledTags)..remove(tag);
    final newDisabled = Set<LogTag>.from(disabledTags)..add(tag);
    return copyWith(enabledTags: newTags, disabledTags: newDisabled);
  }

  /// Returns a new config with multiple tags enabled (by labels).
  LoggerConfig withTagsEnabled(Iterable<String> labels) {
    final newTags = Set<LogTag>.from(enabledTags);
    final newDisabled = Set<LogTag>.from(disabledTags);
    for (final label in labels) {
      final tag = findTagByLabel(label, allowCustom: true)!;
      newTags.add(tag);
      newDisabled.remove(tag);
    }
    return copyWith(enabledTags: newTags, disabledTags: newDisabled);
  }

  /// Returns a new config with multiple tags disabled (by labels).
  LoggerConfig withTagsDisabled(Iterable<String> labels) {
    final newTags = Set<LogTag>.from(enabledTags);
    final newDisabled = Set<LogTag>.from(disabledTags);
    for (final label in labels) {
      final tag = findTagByLabel(label, allowCustom: true)!;
      newTags.remove(tag);
      newDisabled.add(tag);
    }
    return copyWith(enabledTags: newTags, disabledTags: newDisabled);
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
    bool? enableNetworkLogging,
    int? networkPort,
    String? logDirectory,
    Set<LogTag>? enabledTags,
    Set<LogTag>? disabledTags,
    LogPrinter? printer,
    LogOutput? output,
    String? prefixMessage,
    bool? allowCustomTags,
    String? appName,
  }) {
    final newPrefix = prefixMessage ?? this.prefixMessage;
    final prefixChanged =
        prefixMessage != null && prefixMessage != this.prefixMessage;

    return LoggerConfig(
      minLogLevel: minLogLevel ?? this.minLogLevel,
      enableConsoleLogging: enableConsoleLogging ?? this.enableConsoleLogging,
      enableFileLogging: enableFileLogging ?? this.enableFileLogging,
      enableNetworkLogging:
          enableNetworkLogging ?? this.enableNetworkLogging,
      networkPort: networkPort ?? this.networkPort,
      logDirectory: logDirectory ?? this.logDirectory,
      enabledTags: enabledTags ?? this.enabledTags,
      disabledTags: disabledTags ?? this.disabledTags,
      printer: printer ??
          (prefixChanged ? _defaultPrinter(newPrefix) : this.printer),
      output: output ?? this.output,
      prefixMessage: newPrefix,
      allowCustomTags: allowCustomTags ?? this.allowCustomTags,
      appName: appName ?? this.appName,
    );
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  static LogPrinter _defaultPrinter(String prefix) =>
      DPrettyPrinter.minimal();

  static LogPrinter _tracePrinter(String prefix) =>
      DPrettyPrinter.trace();

  static final Set<LogTag> _productionTags = {
    LogTag.payment,
    LogTag.order,
    LogTag.network,
    LogTag.sync,
    LogTag.database,
  };
}
