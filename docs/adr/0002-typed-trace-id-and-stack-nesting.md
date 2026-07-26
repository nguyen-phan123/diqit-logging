# 0002: Typed TraceId and Stack-based Nesting via ZoneTrace

- **Status**: Accepted
- **Date**: 2026-07-24
- **Supersedes**: [0001-zone-based-tracing.md](./0001-zone-based-tracing.md)

## Context

The original `TraceZone` (ADR 0001) carried a single flat `String` trace ID per zone and inherited the parent trace without nesting. This had three limitations:

1. **Loss of nesting context**: When operation A calls operation B, both share trace `t-abc123`. You can't see the call chain in logs.
2. **String-only IDs**: No grouping, no auto-increment, no suffix for retry/failover paths. Every caller hand-rolled their own ID format.
3. **API verbosity**: `runInTraceZone(traceId: 't-xxx')` vs `runInNewTraceZone()` differed only by whether a trace was passed — a subtle distinction easy to misuse.

## Decision

We replaced `TraceZone` (flat string, single-level) with **`TraceId`** (typed identifier) + **`ZoneTrace`** (stack-based zone carrier).

### TraceId: Typed identifiers

Three factories replace ad-hoc string construction:

| Factory | Format | Use case |
|---|---|---|
| `TraceId.manual('order', 12345)` | `#order-12345` | External ID from order system |
| `TraceId.auto('payment')` | `#payment-1`, `#payment-2`, ... | Auto-increment per subsystem |
| `TraceId.global()` | `#1`, `#2`, ... | Shared counter, no subsystem |

All support `.withSuffix('retry')` → `#order-12345.retry` for retry/fallback marking.

### ZoneTrace: Stack-based nesting

Instead of inheriting a flat string, each `runTraced()` appends to a **trace stack**. The innermost (most recent) trace is always `currentTrace()`. The full stack is available via `currentTraceList()`.

```
DiqitLogger.runTraced(TraceId.manual('outer', 1), () {
  DiqitLogger.i('A');                    // [#outer-1]
  DiqitLogger.runTraced(TraceId.manual('inner', 2), () {
    DiqitLogger.i('B');                  // [#outer-1 > #inner-2]
  });
  DiqitLogger.i('C');                    // [#outer-1]
});
```

### API migration

| Old (0001) | New (0002) |
|---|---|
| `DiqitLogger.runInTraceZone(body, traceId: 't-xxx')` | `DiqitLogger.runTraced(TraceId.manual('xxx', 1), body)` |
| `DiqitLogger.runInNewTraceZone(body)` | `DiqitLogger.runTraced(TraceId.global(), body)` |
| `DiqitLogger.currentTraceId` → `String?` | `DiqitLogger.currentTraceId` → `TraceId?` |

### Error interception

Uncaught errors in a traced zone are forwarded to `ZoneTrace.onError`, a callback set by `DiqitLogger` during initialization. The error is logged with the active `TraceId` before propagating to the parent zone.

### Log format

```
[LEVEL] [TAG] -> [#group-num] message
```

The `[#traceId]` prefix is embedded in `DLogMessage.toString()`, not injected by the printer. This avoids duplicate trace prefixes that occurred in ADR 0001.

## Consequences

- **Positive**: Trace chains are visible in log output (`#outer-1 > #inner-2`). Developers can see the call hierarchy at a glance.
- **Positive**: `TraceId` factories enforce a consistent naming scheme across the codebase.
- **Negative**: Breaking change for any code referencing `TraceZone`, `runInTraceZone`, or `runInNewTraceZone`.
- **Negative**: `ZoneTrace` stack creates more objects per nesting level than the flat string approach.

## Related ADRs
- [0001: Zone-based Tracing](./0001-zone-based-tracing.md) — Superseded by this decision
- [0003: Structured Object Logging](./0003-structured-logging-and-namespace-hierarchy.md) — Loggable protocol for entity data layer
