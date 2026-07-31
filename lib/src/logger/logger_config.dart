import 'package:logger/logger.dart';

import 'package:diqit_logging/diqit_logging.dart';

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
  @Deprecated('Use appName instead')
  final String prefixMessage;
  final bool allowCustomTags;
  final List<String>? searchTagPatterns;
  final List<String>? traceIdPatterns;
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
    @Deprecated('Use appName instead') String prefixMessage = '',
    this.allowCustomTags = false,
    this.searchTagPatterns,
    this.traceIdPatterns,
    String? appName,
  })  : prefixMessage = prefixMessage,
        appName = _resolveAppName(appName, prefixMessage),
        enabledTags = enabledTags ?? Set.from(LogTag.values),
        disabledTags = disabledTags ?? {},
        printer = printer ?? _defaultPrinter();

  static String? _resolveAppName(String? appName, String prefixMessage) {
    if (appName != null && appName.isNotEmpty) return appName;
    if (prefixMessage.isEmpty) return null;
    var cleaned = prefixMessage.trim();
    if (cleaned.startsWith('[')) cleaned = cleaned.substring(1);
    if (cleaned.endsWith(']')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned.trim().isNotEmpty ? cleaned.trim() : null;
  }

  // ---------------------------------------------------------------------------
  // Factory Constructors
  // ---------------------------------------------------------------------------

  /// Development config: verbose, all tags, row-based printer.
  factory LoggerConfig.development({
    String? logDirectory,
    @Deprecated('Use appName instead') String prefixMessage = '',
    LogLevel? minLogLevel,
    List<String>? searchTagPatterns,
    String? appName,
    LogPrinter? printer,
  }) {
    const envTag = String.fromEnvironment('LOG_TAGS', defaultValue: '');
    const envTrace = String.fromEnvironment('LOG_TRACE', defaultValue: '');

    final resolvedPatterns = searchTagPatterns ??
        (envTag.isNotEmpty
            ? envTag.split(',').map((e) => e.trim()).toList()
            : null);

    final resolvedTracePatterns = envTrace.isNotEmpty
        ? envTrace.split(',').map((e) => e.trim()).toList()
        : null;

    return LoggerConfig(
      minLogLevel: minLogLevel ?? LogLevel.trace,
      enableConsoleLogging: true,
      enableFileLogging: false,
      logDirectory: logDirectory,
      enabledTags: Set.from(LogTag.values),
      printer: printer ?? RowPrinter(),
      prefixMessage: prefixMessage,
      allowCustomTags: true,
      searchTagPatterns: resolvedPatterns,
      traceIdPatterns: resolvedTracePatterns,
      appName: appName,
    );
  }

  /// Production config: warnings+, critical tags only, file logging enabled.
  factory LoggerConfig.production({
    String? logDirectory,
    @Deprecated('Use appName instead') String prefixMessage = '',
    List<String>? searchTagPatterns,
    String? appName,
    LogPrinter? printer,
  }) {
    return LoggerConfig(
      minLogLevel: LogLevel.warning,
      enableConsoleLogging: true,
      enableFileLogging: true,
      logDirectory: logDirectory,
      enabledTags: _productionTags,
      printer: printer ?? RowPrinter(enableColors: false),
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
    List<String>? traceIdPatterns,
    String? appName,
  }) {
    final newPrefix = prefixMessage ?? this.prefixMessage;
    final prefixChanged =
        prefixMessage != null && prefixMessage != this.prefixMessage;

    return LoggerConfig(
      minLogLevel: minLogLevel ?? this.minLogLevel,
      enableConsoleLogging: enableConsoleLogging ?? this.enableConsoleLogging,
      enableFileLogging: enableFileLogging ?? this.enableFileLogging,
      enableNetworkLogging: enableNetworkLogging ?? this.enableNetworkLogging,
      networkPort: networkPort ?? this.networkPort,
      logDirectory: logDirectory ?? this.logDirectory,
      enabledTags: enabledTags ?? this.enabledTags,
      disabledTags: disabledTags ?? this.disabledTags,
      printer: printer ?? this.printer,
      output: output ?? this.output,
      prefixMessage: newPrefix,
      allowCustomTags: allowCustomTags ?? this.allowCustomTags,
      traceIdPatterns: traceIdPatterns ?? this.traceIdPatterns,
      appName: appName ?? this.appName,
    );
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  static LogPrinter _defaultPrinter() => RowPrinter();

  static final Set<LogTag> _productionTags = {
    LogTag.network,
    LogTag.sync,
    LogTag.database,
  };
}
