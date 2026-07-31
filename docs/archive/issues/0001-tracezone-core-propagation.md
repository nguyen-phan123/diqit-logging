# Issue 1: Implement `TraceZone` Core Utility with Async Context Propagation and Error Interception

## Parent

PRD: Zone-based Tracing (`TraceZone`) for Mobile POS Systems ([0001-zone-based-tracing-prd.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/prd/0001-zone-based-tracing-prd.md))

## What to build

Build the core `TraceZone` utility class in `packages/diqit-logging` to manage `Zone.current[#diqitTraceId]` propagation across asynchronous Dart execution paths (`Future`, `Stream`). `TraceZone` must automatically inherit trace IDs for nested zones, provide helpers to create new trace IDs, and intercept uncaught async errors within the zone to log them with the trace ID before delegating error handling to parent zones.

## Acceptance criteria

- [ ] `TraceZone.currentTraceId` retrieves the active trace ID from `Zone.current[#diqitTraceId]`.
- [ ] `TraceZone.runInTraceZone(traceId, callback)` executes `callback` within a zone containing `traceId`.
- [ ] `TraceZone.runInNewTraceZone(callback)` generates a short unique trace ID (e.g. `t-a1b2c3d4`) and executes `callback`.
- [ ] Nested `TraceZone` calls inherit the parent zone's `traceId` by default.
- [ ] Uncaught async exceptions in a `TraceZone` are logged with `DiqitLogger.e` (including `traceId` and stack trace) before being rethrown/forwarded to the parent zone handler.
- [ ] Unit tests in `test/src/trace_zone_test.dart` verify context propagation across `Future` and `Stream` calls.

## Blocked by

None - can start immediately.
