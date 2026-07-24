import 'dart:convert';

import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:diqit_logging/src/logger/trace_id.dart';

class DLogMessage {
  final String message;
  final LogTag tag;
  final dynamic data;
  final TraceId? traceId;

  const DLogMessage(
    this.message, [
    this.tag = LogTag.none,
    this.data,
    this.traceId,
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
      buffer.write('\n${_formatData(data)}');
    }

    return buffer.toString();
  }

  static String _formatData(dynamic data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(
        data is String ? data : _toJsonSafe(data),
      );
      return '{\n  "data": $jsonString\n}';
    } catch (_) {
      return '{\n  "data": $data\n}';
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
    // Try toJson() if available (e.g. entities/DTOs)
    try {
      // ignore: avoid_dynamic_calls
      return _toJsonSafe((value as dynamic).toJson());
    } catch (_) {
      return value.toString();
    }
  }
}
