# 0001: Zone-based Tracing for Mobile POS Cross-App Log Correlation

- **Status**: Superseded by 0002
- **Date**: 2026-07-24
- **Superseded by**: [0002-typed-trace-id-and-stack-nesting.md](./0002-typed-trace-id-and-stack-nesting.md)

## Context & Decision

Mobile POS applications (KDS, OT, Dispatch, Customer Display) communicate via Socket.IO events over an asynchronous, event-driven Flutter architecture. Stack-trace parsing (`DiqitLogger.flow()`) is insufficient because it breaks under release obfuscation and cannot correlate logs across process or network boundaries.

We initially adopted **Zone-based tracing (`TraceZone`)** inside `diqit-logging`. A `trace_id` was automatically propagated across Dart `Future`/`Stream` boundaries via `Zone.current` and threaded through Socket.IO event payloads across apps.

## Key Technical Specifications (Original)

1. **Wire Transport (Socket Envelope)**:
   - Socket.IO payloads use standard metadata envelope format: `{ "meta": { "traceId": "..." }, "data": { ... } }`.
   - Socket Listener Middleware automatically extracts `meta.traceId` and wraps event processing in `TraceZone.runInTraceZone(traceId, callback)`.

2. **API Surface & Implicit Zone Extraction**:
   - `DiqitLogger` reads active `trace_id` implicitly via `Zone.current[#diqitTraceId]`.
   - Utility API `DiqitLogger.runInTraceZone(traceId, callback)` and `DiqitLogger.runInNewTraceZone(callback)` manage Zone boundaries.

3. **Trace ID Format & Inheritance**:
   - Uses compact flat IDs (e.g., `t-a1b2c3d4`).
   - Nested zones inherit the parent `trace_id` by default.

4. **Error Interception**:
   - Uncaught async errors within a `TraceZone` are logged with the active `trace_id` before being forwarded to top-level Flutter/Dart error handlers.

5. **Log Format & Filtering**:
   - Output log lines format: `YYYY-MM-DD HH:mm:ss.SSS [LEVEL] [TAG] [trace:t-a1b2c3d4] Message`.
   - Exposes filtering APIs: `DiqitLogger.exportLogsForTrace(traceId)` and `DiqitLogger.getLogHistoryForTrace(traceId)`.
