/// {@template trace_id}
/// A unique identifier for tracing a logical operation across async boundaries.
///
/// Three factory constructors provide different trace ID strategies:
/// - [TraceId.manual] — explicit group + number
/// - [TraceId.auto] — lazy auto-incrementing per group
/// - [TraceId.global] — shared counter across all groups
///
/// Example:
/// ```dart
/// final trace1 = TraceId.manual('payment', 42);  // #payment-42
/// final trace2 = TraceId.auto('sync');           // #sync-1, #sync-2, ...
/// final trace3 = TraceId.global();               // #1, #2, #3, ...
/// final trace4 = trace1.withSuffix('retry');     // #payment-42.retry
/// ```
/// {@endtemplate}
// ignore: one_member_abstracts
abstract class TraceId {
  /// {@macro trace_id}
  const TraceId._();

  /// Creates a manual trace ID with explicit [group] and [num].
  ///
  /// Use when you have an external correlation ID (order ID, user ID, etc.).
  ///
  /// Example:
  /// ```dart
  /// final trace = TraceId.manual('order', orderId);  // #order-12345
  /// ```
  factory TraceId.manual(String group, int num) = _ManualTraceId;

  /// Creates an auto-incrementing trace ID for the given [group].
  ///
  /// Counter is lazy — only increments when [toString] is called.
  /// Each group maintains its own independent counter.
  ///
  /// Example:
  /// ```dart
  /// final trace1 = TraceId.auto('payment');  // #payment-1
  /// final trace2 = TraceId.auto('payment');  // #payment-2
  /// final trace3 = TraceId.auto('sync');     // #sync-1
  /// ```
  factory TraceId.auto(String group) = _AutoTraceId;

  /// Creates a global auto-incrementing trace ID (no group).
  ///
  /// Counter is shared across all global traces.
  ///
  /// Example:
  /// ```dart
  /// final trace1 = TraceId.global();  // #1
  /// final trace2 = TraceId.global();  // #2
  /// ```
  factory TraceId.global() = _GlobalTraceId;

  /// Returns a new trace ID with [suffix] appended.
  ///
  /// Useful for marking retry attempts, fallback paths, or nested operations.
  ///
  /// Example:
  /// ```dart
  /// final trace = TraceId.auto('payment');
  /// final retry = trace.withSuffix('retry');  // #payment-1.retry
  /// ```
  TraceId withSuffix(String suffix);
}

/// Manual trace ID with explicit group + num.
class _ManualTraceId extends TraceId {
  const _ManualTraceId(this.group, this.num, [this.suffix]) : super._();

  final String group;
  final int num;
  final String? suffix;

  @override
  TraceId withSuffix(String suffix) => _ManualTraceId(group, num, suffix);

  @override
  String toString() {
    final base = '#$group-$num';
    return suffix != null ? '$base.$suffix' : base;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ManualTraceId &&
          group == other.group &&
          num == other.num &&
          suffix == other.suffix;

  @override
  int get hashCode => Object.hash(group, num, suffix);
}

/// Auto-incrementing trace ID per group.
class _AutoTraceId extends TraceId {
  _AutoTraceId(this.group, [this.suffix])
      : _counter = _getCounter(group),
        super._();

  final String group;
  final String? suffix;
  final _LazyCounter _counter;

  static final Map<String, _LazyCounter> _counters = {};

  static _LazyCounter _getCounter(String group) =>
      _counters.putIfAbsent(group, _LazyCounter.new);

  @override
  TraceId withSuffix(String suffix) => _AutoTraceId(group, suffix).._num = _num;

  int? _num;

  int get _resolvedNum => _num ??= _counter.next();

  @override
  String toString() {
    final base = '#$group-$_resolvedNum';
    return suffix != null ? '$base.$suffix' : base;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AutoTraceId &&
          group == other.group &&
          _resolvedNum == other._resolvedNum &&
          suffix == other.suffix;

  @override
  int get hashCode => Object.hash(group, _resolvedNum, suffix);
}

/// Global auto-incrementing trace ID (no group).
class _GlobalTraceId extends TraceId {
  _GlobalTraceId([this.suffix]) : super._();

  final String? suffix;

  static final _LazyCounter _counter = _LazyCounter();

  int? _num;

  int get _resolvedNum => _num ??= _counter.next();

  @override
  TraceId withSuffix(String suffix) => _GlobalTraceId(suffix).._num = _num;

  @override
  String toString() {
    final base = '#$_resolvedNum';
    return suffix != null ? '$base.$suffix' : base;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GlobalTraceId &&
          _resolvedNum == other._resolvedNum &&
          suffix == other.suffix;

  @override
  int get hashCode => Object.hash(_resolvedNum, suffix);
}

/// Lazy counter that only increments when accessed.
class _LazyCounter {
  int _value = 0;

  int next() => ++_value;
}
