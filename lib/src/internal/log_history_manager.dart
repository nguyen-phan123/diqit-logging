import 'package:logger/logger.dart';

/// Internal helper to manage log history and export.
class LogHistoryManager {
  late final MemoryOutput _memoryOutput;

  LogHistoryManager({int bufferSize = 1000}) {
    _memoryOutput = MemoryOutput(bufferSize: bufferSize);
  }

  /// Returns the internal MemoryOutput for attaching to Logger.
  MemoryOutput get output => _memoryOutput;

  /// Returns a snapshot of recent log events.
  List<OutputEvent> getLogHistory() => _memoryOutput.buffer.toList();

  /// Exports the recent logs as a formatted string.
  String exportLogs({int? lastN}) {
    var entries = _memoryOutput.buffer.toList();
    if (lastN != null && entries.length > lastN) {
      entries = entries.sublist(entries.length - lastN);
    }

    final buffer = StringBuffer();
    buffer.writeln('=== DiqitLogger Export ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 50);

    for (final event in entries) {
      for (final line in event.lines) {
        buffer.writeln(line);
      }
      buffer.writeln('-' * 20);
    }
    return buffer.toString();
  }

  /// Returns a snapshot of log events matching [traceId].
  List<OutputEvent> getLogHistoryForTrace(String traceId) {
    final searchTag = '[$traceId]';
    return _memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();
  }

  /// Returns a snapshot of log events matching a context key-value pair.
  ///
  /// Searches for the JSON pattern `"key": value` in log lines.
  /// Handles string and numeric values.
  ///
  /// Example:
  /// ```dart
  /// // Find all logs related to order ORD-001
  /// final orderLogs = history.getLogHistoryByContext('order_id', 'ORD-001');
  /// ```
  List<OutputEvent> getLogHistoryByContext(
    String key,
    dynamic value,
  ) {
    final searchPattern = value is String
        ? '"$key":"$value"'
        : '"$key":$value';
    return _memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchPattern));
    }).toList();
  }

  /// Returns a snapshot of log events matching a namespace [path].
  ///
  /// Matches the ns path format `[path]` in log lines.
  ///
  /// Example:
  /// ```dart
  /// final orderGridLogs = history.getLogHistoryByPath('kds/order_grid');
  /// ```
  List<OutputEvent> getLogHistoryByPath(String path) {
    final searchTag = '[$path]';
    return _memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();
  }

  /// Exports logs matching [traceId] as a formatted string.
  String exportLogsForTrace(String traceId, {int? lastN}) {
    final searchTag = '[$traceId]';
    var entries = _memoryOutput.buffer.where((event) {
      return event.lines.any((line) => line.contains(searchTag));
    }).toList();

    if (lastN != null && entries.length > lastN) {
      entries = entries.sublist(entries.length - lastN);
    }

    final buffer = StringBuffer();
    buffer.writeln('=== DiqitLogger Trace Export [$traceId] ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 50);

    for (final event in entries) {
      for (final line in event.lines) {
        buffer.writeln(line);
      }
      buffer.writeln('-' * 20);
    }
    return buffer.toString();
  }
}
