import 'package:diqit_logging/src/logger/trace_id.dart';
import 'package:diqit_logging/src/logger/zone_trace.dart';

/// {@template trace_envelope}
/// Helper utilities to extract and inject `traceId` metadata into/from
/// Socket.IO event transport envelopes.
/// {@endtemplate}
class TraceEnvelope {
  TraceEnvelope._();

  /// Key name used in payload metadata envelope.
  static const String metaKey = 'meta';

  /// Trace ID key inside metadata map.
  static const String traceIdKey = 'traceId';

  /// Extracts `traceId` from [payload] if present under `meta.traceId`.
  static String? extractTraceId(dynamic payload) {
    if (payload is Map) {
      final meta = payload[metaKey];
      if (meta is Map) {
        final traceId = meta[traceIdKey];
        if (traceId is String && traceId.isNotEmpty) {
          return traceId;
        }
      }
      final directTraceId = payload[traceIdKey];
      if (directTraceId is String && directTraceId.isNotEmpty) {
        return directTraceId;
      }
    }
    return null;
  }

  /// Injects [traceId] (or active Zone trace) into [payload].
  ///
  /// Returns a new [Map] containing
  /// `{ "meta": { "traceId": traceId, ... }, ... }`.
  static Map<String, dynamic> injectTraceId(
    Map<String, dynamic> payload, {
    TraceId? traceId,
  }) {
    final effectiveTrace = traceId ??
        ZoneTrace.currentTrace() ??
        TraceId.global();

    final result = Map<String, dynamic>.from(payload);
    final meta = result[metaKey] is Map
        ? Map<String, dynamic>.from(result[metaKey] as Map)
        : <String, dynamic>{};

    meta[traceIdKey] = effectiveTrace.toString();
    result[metaKey] = meta;

    return result;
  }
}
