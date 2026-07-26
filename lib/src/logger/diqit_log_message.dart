import 'dart:convert';

import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/logger/loggable.dart';
import 'package:diqit_logging/src/logger/trace_id.dart';
import 'package:diqit_logging/src/logger/type_converter.dart';

class DLogMessage {
  final String message;
  final LogTag tag;
  final dynamic data;
  final TraceId? traceId;
  final TypeConverterRegistry? typeConverterRegistry;

  const DLogMessage(
    this.message, [
    this.tag = LogTag.none,
    this.data,
    this.traceId,
    this.typeConverterRegistry,
  ]);

  @override
  String toString() {
    final buffer = StringBuffer();

    // Add trace ID prefix if present
    if (traceId != null) {
      buffer.write('[$traceId] ');
    }

    buffer.write(message);

    if (data != null) {
      buffer.write('\n${_formatData(data, typeConverterRegistry)}');
    }

    return buffer.toString();
  }

  static String _formatData(
    dynamic data,
    TypeConverterRegistry? registry,
  ) {
    // 1. Check if data implements Loggable
    if (data is Loggable) {
      try {
        final loggableMap = data.toLoggableMap();
        return _formatLoggableMap(loggableMap);
      } catch (e) {
        return 'Data: [Loggable formatting error: $e]';
      }
    }

    // 2. Check if TypeConverter exists for this type
    if (registry != null && data is Object) {
      final converted = registry.convert(data);
      if (converted != null) {
        return 'Data: $converted';
      }
    }

    // 3. Fallback to JSON encoding (legacy behavior)
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(
        data is String ? data : _toJsonSafe(data),
      );
      return 'Data:\n{\n  "data": $jsonString\n}';
    } catch (_) {
      return 'Data:\n{\n  "data": $data\n}';
    }
  }

  static String _formatLoggableMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return 'Data: {}';
    }

    final buffer = StringBuffer('Data: {');
    final entries = map.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final formattedValue = _formatLoggableValue(entry.value);
      buffer.write('${entry.key}: $formattedValue');
      if (i < entries.length - 1) {
        buffer.write(', ');
      }
    }

    buffer.write('}');
    return buffer.toString();
  }

  /// Recursively format a value from a Loggable map
  static String _formatLoggableValue(dynamic value) {
    if (value is Loggable) {
      final nestedMap = value.toLoggableMap();
      if (nestedMap.isEmpty) return '{}';

      final buffer = StringBuffer('{');
      final entries = nestedMap.entries.toList();

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final formattedValue = _formatLoggableValue(entry.value);
        buffer.write('${entry.key}: $formattedValue');
        if (i < entries.length - 1) {
          buffer.write(', ');
        }
      }

      buffer.write('}');
      return buffer.toString();
    }

    return value.toString();
  }

  static dynamic _toJsonSafe(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toJsonSafe(v)));
    }
    if (value is Iterable) {
      return value.map(_toJsonSafe).toList();
    }
    // Try toJson() if available (e.g. entities/DTOs)
    try {
      // ignore: avoid_dynamic_calls
      return _toJsonSafe((value as dynamic).toJson());
    } catch (_) {
      return value.toString();
    }
  }
}
