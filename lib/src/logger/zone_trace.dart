import 'dart:async';

import 'package:diqit_logging/src/logger/trace_id.dart';

/// Zone key for storing trace ID stack.
const Symbol _traceStackKey = #diqit_logging_trace_stack;

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

  /// Runs [fn] in a new Zone with [traceId] added to the trace stack.
  ///
  /// Any logs emitted within [fn] (or async operations spawned from it) will
  /// inherit [traceId] automatically.
  ///
  /// Errors thrown by [fn] itself propagate to the caller via the returned
  /// Future. Uncaught errors from microtasks, timers, or stream callbacks
  /// within the zone are forwarded to [onError] before propagating to the
  /// parent zone.
  ///
  /// Example:
  /// ```dart
  /// await ZoneTrace.runTraced(TraceId.auto('payment'), () async {
  ///   DiqitLogger.info('Processing payment');  // Inherits trace
  ///   await _chargeCard();                     // Nested calls inherit too
  /// });
  /// ```
  static Future<T> runTraced<T>(
    TraceId traceId,
    Future<T> Function() fn,
  ) async {
    final newStack = List<TraceId>.from(_currentStack())..add(traceId);
    final completer = Completer<T>();

    // Launch fn() in a new zone. Errors from fn() flow through the Future
    // chain so the caller can catch them. Microtask/timer/stream errors
    // within the zone are caught by runZonedGuarded's onError.
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
      zoneValues: {_traceStackKey: newStack},
    );

    return completer.future;
  }

  /// Synchronous version of [runTraced].
  ///
  /// Example:
  /// ```dart
  /// ZoneTrace.runTracedSync(TraceId.manual('init', 1), () {
  ///   DiqitLogger.debug('Initialization started');
  ///   _loadConfig();
  /// });
  /// ```
  static T runTracedSync<T>(
    TraceId traceId,
    T Function() fn,
  ) {
    final newStack = List<TraceId>.from(_currentStack())..add(traceId);
    return runZoned(
      fn,
      zoneValues: {_traceStackKey: newStack},
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
}
