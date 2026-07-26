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
  final Map<String, dynamic>? context;
  final String? path;
  final String? source;
  final String prefix;

  const DLogMessage({
    required this.message,
    this.tag = LogTag.none,
    this.data,
    this.traceId,
    this.typeConverterRegistry,
    this.context,
    this.path,
    this.source,
    this.prefix = '',
  });

  @override
  String toString() {
    final buffer = StringBuffer();

    if (prefix.isNotEmpty) {
      buffer.write(prefix);
    }

    final decorations = <String>[];
    if (source != null && source!.isNotEmpty) {
      decorations.add('[$source]');
    }
    if (tag.label.isNotEmpty) {
      decorations.add('[${tag.label}]');
    }
    if (path != null && path!.isNotEmpty) {
      decorations.add('[$path]');
    }
    if (decorations.isNotEmpty) {
      buffer.write('${decorations.join(' ')} -> ');
    }

    if (traceId != null) {
      buffer.write('[$traceId] ');
    }

    if (context != null && context!.isNotEmpty) {
      buffer.write(_formatContext(context!));
      buffer.write(' ');
    }

    buffer.write(message);

    if (data != null) {
      buffer.write(_formatData(data, typeConverterRegistry));
    }

    return buffer.toString();
  }

  static String _formatContext(Map<String, dynamic> context) {
    try {
      return jsonEncode(context);
    } catch (_) {
      return context.toString();
    }
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
        return ' [Loggable formatting error: $e]';
      }
    }

    // 2. Check if TypeConverter exists for this type
    if (registry != null && data is Object) {
      final converted = registry.convert(data);
      if (converted != null) {
        return ' "$converted"';
      }
    }

    // 3. Fallback to JSON encoding
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(
        data is String ? data : _toJsonSafe(data),
      );
      return ' {"data": $jsonString}';
    } catch (_) {
      return ' {"data": "$data"}';
    }
  }

  static String _formatLoggableMap(Map<String, dynamic> map) {
    if (map.isEmpty) return ' {}';

    final buffer = StringBuffer(' {\n');
    _writeJsonEntries(buffer, map, 2);
    buffer.write('}');
    return buffer.toString();
  }

  /// Recursively format a value from a Loggable map as JSON
  static String _formatLoggableValue(dynamic value, int indent) {
    if (value is Loggable) {
      final nestedMap = value.toLoggableMap();
      if (nestedMap.isEmpty) return '{}';

      final buffer = StringBuffer('{\n');
      _writeJsonEntries(buffer, nestedMap, indent + 2);
      buffer.write('${' ' * indent}}');
      return buffer.toString();
    }

    if (value is String) {
      return '"$value"';
    }

    return value.toString();
  }

  /// Writes JSON object entries with proper indentation and commas
  static void _writeJsonEntries(
    StringBuffer buffer,
    Map<String, dynamic> map,
    int indent,
  ) {
    final indentStr = ' ' * indent;
    final entries = map.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final comma = i < entries.length - 1 ? ',' : '';
      final formattedValue = _formatLoggableValue(entry.value, indent);
      buffer.write('$indentStr"${entry.key}": $formattedValue$comma\n');
    }
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
    try {
      // ignore: avoid_dynamic_calls
      return _toJsonSafe((value as dynamic).toJson());
    } catch (_) {
      return value.toString();
    }
  }
}
