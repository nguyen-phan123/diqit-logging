import 'dart:async';

import 'package:diqit_logging/src/logger/trace_id.dart';

/// Zone key for storing trace ID stack.
const Symbol _traceStackKey = #diqit_logging_trace_stack;

/// Zone key for storing structured context metadata.
const Symbol _contextKey = #diqit_logging_context;

/// Signature for ZoneTrace error handler.
///
/// Called when an uncaught error occurs within a traced zone.
typedef ZoneTraceErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
  TraceId traceId,
);

/// {@template zone_trace}
/// Utilities for Zone-based trace propagation.
///
/// Traces are stored as a stack in Zone values, allowing automatic inheritance
/// across async boundaries without manual parameter passing.
///
/// Structured [context] (entity IDs, operation metadata) can be attached and
/// inherited alongside trace IDs for independent filtering.
///
/// Uncaught errors within traced zones are intercepted and forwarded to
/// [onError], which should be configured to log through the application's
/// logging system.
/// {@endtemplate}
class ZoneTrace {
  ZoneTrace._();

  /// Error handler invoked for uncaught errors inside traced zones.
  ///
  /// Set by the application's logger (e.g., [DiqitLogger]) during
  /// initialization. If null, uncaught errors are silently passed to the
  /// parent zone's error handler without additional logging.
  static ZoneTraceErrorHandler? onError;

  /// Returns the current trace ID from the Zone stack, or null if none.
  ///
  /// When multiple traces are active (nested [runTraced] calls), returns
  /// the most recent one.
  static TraceId? currentTrace() {
    final stack = _currentStack();
    return stack.isEmpty ? null : stack.last;
  }

  /// Returns the full trace ID stack from the current Zone.
  ///
  /// Useful for building breadcrumb trails or understanding nested operations.
  static List<TraceId> currentTraceList() => List.unmodifiable(_currentStack());

  /// Returns the current structured context from the Zone, or null.
  ///
  /// Context carries entity identifiers and operation metadata (e.g.,
  /// order_id, user_id) separately from the trace identity, enabling
  /// independent filtering by entity across multiple operations.
  ///
  /// When multiple traces are active, returns the context from the
  /// innermost zone that set one.
  static Map<String, dynamic>? currentContext() {
    final ctx = Zone.current[_contextKey];
    return ctx is Map<String, dynamic>? ? ctx : null;
  }

  /// Runs [fn] in a new Zone with [traceId] added to the trace stack.
  ///
  /// Optional [context] carries structured metadata (entity IDs, etc.) that
  /// is inherited by logs within this zone. When null, inherits the parent
  /// zone's context.
  ///
  /// Example:
  /// ```dart
  /// await ZoneTrace.runTraced(
  ///   TraceId.auto('payment'),
  ///   () async {
  ///     DiqitLogger.info('Processing payment');  // Inherits trace
  ///     await _chargeCard();
  ///   },
  ///   context: {'order_id': 'ORD-001'},
  /// );
  /// ```
  static Future<T> runTraced<T>(
    TraceId traceId,
    Future<T> Function() fn, {
    Map<String, dynamic>? context,
  }) async {
    final newStack = List<TraceId>.from(_currentStack())..add(traceId);
    final completer = Completer<T>();

    final zoneValues = <Symbol, Object>{_traceStackKey: newStack};
    final newContext = context ?? ZoneTrace.currentContext();
    if (newContext != null) {
      zoneValues[_contextKey] = newContext;
    }

    runZonedGuarded(
      () {
        fn().then(
          completer.complete,
          onError: (Object e, StackTrace st) {
            _handleError(newStack.last, e, st);
            completer.completeError(e, st);
          },
        );
      },
      (Object error, StackTrace stackTrace) {
        _handleError(newStack.last, error, stackTrace);
      },
      zoneValues: zoneValues,
    );

    return completer.future;
  }

  /// Synchronous version of [runTraced].
  ///
  /// Example:
  /// ```dart
  /// ZoneTrace.runTracedSync(
  ///   TraceId.manual('init', 1),
  ///   () {
  ///     DiqitLogger.debug('Initialization started');
  ///     _loadConfig();
  ///   },
  ///   context: {'boot_phase': 'init'},
  /// );
  /// ```
  static T runTracedSync<T>(
    TraceId traceId,
    T Function() fn, {
    Map<String, dynamic>? context,
  }) {
    final newStack = List<TraceId>.from(_currentStack())..add(traceId);

    final zoneValues = <Symbol, Object>{_traceStackKey: newStack};
    final newContext = context ?? ZoneTrace.currentContext();
    if (newContext != null) {
      zoneValues[_contextKey] = newContext;
    }

    return runZoned(
      fn,
      zoneValues: zoneValues,
      zoneSpecification: ZoneSpecification(
        handleUncaughtError: (self, parent, zone, error, stackTrace) {
          _handleZoneError(zone, error, stackTrace);
          parent.handleUncaughtError(zone, error, stackTrace);
        },
      ),
    );
  }

  /// Returns the trace stack from the current Zone.
  static List<TraceId> _currentStack() {
    final stack = Zone.current[_traceStackKey];
    return stack is List<TraceId> ? stack : <TraceId>[];
  }

  /// Logs an error through [onError] using a trace read from zone values.
  static void _handleZoneError(
    Zone zone,
    Object error,
    StackTrace stackTrace,
  ) {
    final stack = zone[_traceStackKey];
    if (stack is List<TraceId> && stack.isNotEmpty) {
      _handleError(stack.last, error, stackTrace);
    }
  }

  /// Forwards an error to [onError] if configured.
  static void _handleError(
    TraceId traceId,
    Object error,
    StackTrace stackTrace,
  ) {
    onError?.call(error, stackTrace, traceId);
  }

  // ---------------------------------------------------------------------------
  // Socket.IO Metadata Transport
  // ---------------------------------------------------------------------------

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
        currentTrace() ??
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
