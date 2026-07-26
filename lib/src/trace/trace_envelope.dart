import 'package:diqit_logging/src/logger/trace_id.dart';
import 'package:diqit_logging/src/logger/zone_trace.dart';

/// {@template trace_envelope}
/// Helper utilities to extract and inject metadata into/from
/// Socket.IO event transport envelopes.
///
/// Metadata injected:
/// - [traceIdKey]: active trace ID from zone or explicit parameter
/// - [sourceKey]: app identity from [sourceAppName] (auto-injected when set)
/// {@endtemplate}
class TraceEnvelope {
  TraceEnvelope._();

  /// Key name used in payload metadata envelope.
  static const String metaKey = 'meta';

  /// Trace ID key inside metadata map.
  static const String traceIdKey = 'traceId';

  /// Source (app name) key inside metadata map.
  static const String sourceKey = 'source';

  /// Application identity for cross-app source attribution.
  ///
  /// Set by [DiqitLogger] during initialization from [LoggerConfig.appName].
  /// When non-null, [injectTraceId] automatically includes `meta.source`.
  static String? sourceAppName;

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

  /// Extracts `source` from [payload] if present under `meta.source`.
  static String? extractSource(dynamic payload) {
    if (payload is Map) {
      final meta = payload[metaKey];
      if (meta is Map) {
        final source = meta[sourceKey];
        if (source is String && source.isNotEmpty) {
          return source;
        }
      }
    }
    return null;
  }

  /// Injects trace ID and optional source into [payload].
  ///
  /// Returns a new [Map] containing
  /// `{ "meta": { "traceId": ..., "source": ... }, ... }`.
  ///
  /// [sourceAppName] is auto-injected when set.
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
    if (sourceAppName != null) {
      meta[sourceKey] = sourceAppName;
    }
    result[metaKey] = meta;

    return result;
  }
}
