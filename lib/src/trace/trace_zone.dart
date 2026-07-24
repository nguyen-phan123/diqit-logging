import 'dart:async';
import 'dart:math';

import 'package:diqit_logging/diqit_logging.dart';

const Symbol _diqitTraceIdKey = #diqitTraceId;

/// {@template trace_zone}
/// Manages execution contexts powered by Dart [Zone] to carry and propagate
/// diagnostic correlation metadata (`trace_id`) across async boundaries.
/// {@endtemplate}
class TraceZone {
  TraceZone._();

  static final Random _random = Random();

  /// Returns the current active trace ID from [Zone.current], or `null` if
  /// not inside an active [TraceZone].
  static String? get currentTraceId =>
      Zone.current[_diqitTraceIdKey] as String?;

  /// Generates a compact unique trace ID (e.g. `t-189f2a-a1b2c3`).
  static String generateTraceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final randomBits =
        _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 't-$timestamp-$randomBits';
  }

  /// Runs [body] inside a [TraceZone] associated with [traceId].
  ///
  /// If [traceId] is omitted or `null`, it will inherit [currentTraceId] if
  /// available, or generate a new trace ID.
  static R runInTraceZone<R>(
    R Function() body, {
    String? traceId,
  }) {
    final effectiveTraceId = traceId ?? currentTraceId ?? generateTraceId();

    return runZoned(
      body,
      zoneValues: {_diqitTraceIdKey: effectiveTraceId},
      zoneSpecification: ZoneSpecification(
        handleUncaughtError: (self, parent, zone, error, stackTrace) {
          DiqitLogger.e(
            'Uncaught error in TraceZone [$effectiveTraceId]: $error',
            error: error,
            stackTrace: stackTrace,
          );
          parent.handleUncaughtError(zone, error, stackTrace);
        },
      ),
    );
  }

  /// Runs [body] inside a newly generated [TraceZone], forcing a fresh
  /// trace ID even if called within an existing parent [TraceZone].
  static R runInNewTraceZone<R>(
    R Function() body, {
    String? customTraceId,
  }) {
    final newTraceId = customTraceId ?? generateTraceId();
    return runInTraceZone(body, traceId: newTraceId);
  }
}
