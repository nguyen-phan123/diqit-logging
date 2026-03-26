import 'dart:convert';

import 'package:diqit_logging/src/logger/log_tag.dart';

class DLogMessage {
  final String message;
  final LogTag tag;
  final dynamic data;

  const DLogMessage(this.message, [this.tag = LogTag.none, this.data]);

  @override
  String toString() {
    if (data != null) {
      return '$message\n${_formatData(data)}';
    }
    return message;
  }

  static String _formatData(dynamic data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(
        data is String ? data : _toJsonSafe(data),
      );
      return 'Data: $jsonString';
    } catch (_) {
      return 'Data: $data';
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
