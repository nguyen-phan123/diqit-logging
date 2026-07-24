---
name: use-zone-trace
description: >
  Add zone-based trace propagation to Dart code. Use when the user wants to
  correlate logs across async boundaries, attach a trace ID to a logical
  operation, wrap Socket.IO handlers with trace context, filter log history
  by trace, or when the user mentions "tracing", "trace ID", "correlation",
  "ZoneTrace", or "runTraced". Also use when implementing a BLoC handler,
  repository method, or API call that spans multiple log statements and
  needs them linked.
disable-model-invocation: false
---

# Use ZoneTrace

ZoneTrace attaches a **trace ID** to every log statement inside a
Dart `Zone`, so all logs from an operation — across `await` boundaries,
streams, and nested calls — carry the same correlation tag automatically.
No manual parameter passing needed.

## Quick start

```dart
await DiqitLogger.runTraced(
  TraceId.manual('order', orderId),
  () async {
    DiqitLogger.i('Validating order');    // [#order-12345] Validating order
    await _paymentService.charge();       // inherits [#order-12345]
    DiqitLogger.i('Order complete');      // [#order-12345] Order complete
  },
);
```

Every `DiqitLogger.*` call inside the callback prints `[#order-12345]`
as a prefix. No explicit `traceId:` parameter required.

## Choosing a TraceId

TraceId has three factories — pick the one that matches the data source:

| Factory | Output | When |
|---|---|---|
| `TraceId.manual('group', num)` | `#group-num` | External ID exists (order ID, user ID, socket event ID) |
| `TraceId.auto('group')` | `#group-1`, `#group-2`, ... | Auto-increment per subsystem, no external ID |
| `TraceId.global()` | `#1`, `#2`, ... | Shared counter, no grouping needed |

All support `.withSuffix('retry')`:

```dart
TraceId.manual('order', 12345).withSuffix('retry')  // #order-12345.retry
TraceId.auto('sync').withSuffix('fallback')           // #sync-1.fallback
```

## Nesting traces

`runTraced` creates a **stack**. The innermost trace is always
`currentTrace()`. Nested logs show the full chain:

```dart
await DiqitLogger.runTraced(TraceId.manual('outer', 1), () async {
  DiqitLogger.i('start');                             // [#outer-1]
  await DiqitLogger.runTraced(TraceId.manual('inner', 2), () async {
    DiqitLogger.i('nested');                          // [#outer-1 > #inner-2]
  });
  DiqitLogger.i('back');                              // [#outer-1]
});
```

Use nesting when an operation spawns sub-operations and you want
the call hierarchy visible in logs.

## Overriding the zone trace

Pass `traceId:` explicitly to override the zone trace for a single
log statement:

```dart
await DiqitLogger.runTraced(TraceId.auto('zone'), () async {
  DiqitLogger.i('zone trace');                       // [#zone-1]
  DiqitLogger.i('explicit', traceId: TraceId.manual('custom', 42));  // [#custom-42]
  DiqitLogger.i('back to zone');                     // [#zone-1]
});
```

## Sync code

```dart
DiqitLogger.runTracedSync(
  TraceId.manual('init', 1),
  () {
    DiqitLogger.d('Loading config');  // [#init-1]
    _parseConfig();
  },
);
```

## Error interception

Uncaught errors inside a traced zone are automatically logged with
the trace context before propagating:

```dart
await DiqitLogger.runTraced(TraceId.auto('payment'), () async {
  throw StateError('Charge failed');
  // Logs: ⛔ [#payment-1] Uncaught error in traced zone [#payment-1]: ...
});
```

Configured via `ZoneTrace.onError` (set automatically by `DiqitLogger.initialize`).

## Socket.IO envelope

`TraceEnvelope` reads and writes `traceId` in Socket.IO payload metadata:

```dart
// Inject current zone trace into outgoing payload
final payload = TraceEnvelope.injectTraceId({'orderId': '202'});
// → { meta: { traceId: '#order-202' }, orderId: '202' }

// Extract traceId from incoming event (still a String from the wire)
final rawTraceId = TraceEnvelope.extractTraceId(eventPayload);
// → '#order-202' (as String)

// Re-hydrate with a fresh TraceId for local processing
DiqitLogger.runTraced(
  TraceId.auto('socket'),
  () => _handleEvent(eventPayload),
);
```

## Filtering log history

```dart
// Get all events matching a trace
final events = DiqitLogger.getLogHistoryForTrace('#order-12345');

// Export formatted log for a trace
final logDump = DiqitLogger.exportLogsForTrace('#order-12345');
```

## Patterns

**BLoC handler**: Wrap `handleEvent` in `runTraced` with the event's
correlation ID.

**Repository method**: Wrap each public method in `runTraced` with
`TraceId.auto('RepositoryName')`.

**API call retry**: Use `.withSuffix('retry')` on the existing trace
before re-invoking.

**Background timer**: Use `runTraced` inside `Timer.periodic` or
`Stream.listen` callbacks — the zone keeps the trace alive across ticks.

## API reference

| Method | Returns |
|---|---|
| `DiqitLogger.runTraced(TraceId, Future<T> Function())` | `Future<T>` |
| `DiqitLogger.runTracedSync(TraceId, T Function())` | `T` |
| `DiqitLogger.currentTraceId` | `TraceId?` |
| `ZoneTrace.currentTrace()` | `TraceId?` |
| `ZoneTrace.currentTraceList()` | `List<TraceId>` |
| `ZoneTrace.runTraced(TraceId, Future<T> Function())` | `Future<T>` |
| `ZoneTrace.runTracedSync(TraceId, T Function())` | `T` |
| `ZoneTrace.onError` | `ZoneTraceErrorHandler?` |
| `TraceEnvelope.injectTraceId(Map, {TraceId?})` | `Map<String, dynamic>` |
| `TraceEnvelope.extractTraceId(dynamic)` | `String?` |
| `DiqitLogger.getLogHistoryForTrace(String)` | `List<OutputEvent>` |
| `DiqitLogger.exportLogsForTrace(String)` | `String` |
