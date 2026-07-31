# PRD: Zone-based Tracing (`TraceZone`) for Mobile POS Systems

## Problem Statement

Mobile POS systems (KDS, OT, Dispatch, Customer Display) communicate via Socket.IO events over asynchronous Dart execution paths (`Future`, `Stream`, BLoC). Traditional stack trace logging is fragile in obfuscated production builds and fails to propagate diagnostic context across asynchronous execution boundaries and cross-application Socket.IO event processing. When troubleshooting multi-app POS issues or customer order bugs, developers cannot correlate log traces across apps or filter local logs for a specific request/order execution flow.

## Solution

Implement **Zone-based Tracing (`TraceZone`)** inside `diqit-logging`. A `trace_id` is automatically propagated across Dart `Future`/`Stream` boundaries via `Zone.current` and threaded through Socket.IO event transport envelopes (`meta.traceId`) across mobile POS applications. Developers log zero-overhead statements (`DiqitLogger.i(...)`), which automatically attach the active `trace_id`. Local log outputs and log history buffers include `[trace:id]` tags and support dedicated trace filtering APIs.

## User Stories

1. As a mobile POS developer, I want logging statements to automatically capture and output the active `trace_id` from the Dart Zone without passing parameters manually, so that I can write clean logging code across BLoC handlers and repositories.
2. As a mobile POS developer, I want to wrap Socket.IO event callbacks in a `TraceZone` using the event's `meta.traceId`, so that log messages across KDS, OT, Dispatch, and Customer Display share a single unified correlation trace ID.
3. As a developer/QA technician, I want to filter and export log history specifically for a single `trace_id` from the in-app debug menu, so that I can inspect exact log sequences for an order without noise from background tasks or heartbeats.
4. As a mobile developer, I want uncaught asynchronous errors occurring within a `TraceZone` to automatically record an error log containing the `trace_id` before escalating to global Flutter error handlers, so that unhandled crashes are accurately attributed to their originating trace.
5. As a system architect, I want nested `TraceZone` execution contexts to inherit parent trace IDs by default, so that multi-step async tasks maintain unbroken correlation trace chains.

## Implementation Decisions

- **Domain Glossary Alignment**: Uses `TraceZone` (Dart Zone execution context carrying trace metadata) and `Trace Envelope` (Socket.IO metadata wrapper) as defined in `CONTEXT.md`.
- **Architectural ADR Compliance**: Adheres strictly to ADR `0001-zone-based-tracing.md`.
- **API Surface**: Exposes static methods on `DiqitLogger`:
  - `DiqitLogger.runInTraceZone(traceId, callback)`
  - `DiqitLogger.runInNewTraceZone(callback)`
  - `DiqitLogger.currentTraceId`
  - `DiqitLogger.getLogHistoryForTrace(traceId)`
  - `DiqitLogger.exportLogsForTrace(traceId)`
- **Implicit Context Storage**: Stores active trace ID under private `Symbol` key `#diqitTraceId` within `Zone.current`.
- **Log Formatting**: Formats file and console log lines with `[trace:t-xxxx]` tag prefix when active.
- **Uncaught Error Interception**: Implements `ZoneSpecification.handleUncaughtError` to log errors via `DiqitLogger.e()` before delegating to parent zone error handling.

## Testing Decisions

- **Testing Seams**: Unit test suite seam (`test/src/trace_zone_test.dart`). Tests verify external behavior of trace context propagation across async boundaries (`Future`, `Stream`), zone inheritance, error interception, line formatting, and trace-filtered history exports.
- **Test Integrity**: Tests do not mock Dart Zone internals; they test public API contracts and verified output log behavior.
- **Prior Art**: Follows standard Dart package testing patterns established in `test/src/diqit_logging_test.dart`.

## Out of Scope

- Remote APM / OpenTelemetry collector export (logs remain in local files & memory buffer).
- Web/Backend server trace propagation protocols outside Socket.IO mobile POS apps.

## Further Notes

- Low maintenance overhead for developers: wrapping Socket listener gateway functions automatically instruments all downstream BLoC/Repository logic.
