# Issue 3: Add Trace-Based History Filtering and Export APIs to `DiqitLogger`

## Parent

PRD: Zone-based Tracing (`TraceZone`) for Mobile POS Systems ([0001-zone-based-tracing-prd.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/prd/0001-zone-based-tracing-prd.md))

## What to build

Update `LogHistoryManager` to store trace ID metadata with each buffered log event. Expose static APIs on `DiqitLogger` (`getLogHistoryForTrace(traceId)` and `exportLogsForTrace(traceId)`) to allow developers and QA testers to inspect and export logs specifically belonging to a single trace ID.

## Acceptance criteria

- [ ] `LogHistoryManager` attaches the active `traceId` to each stored `OutputEvent`.
- [ ] `DiqitLogger.getLogHistoryForTrace(traceId)` returns only the log events matching the specified `traceId`.
- [ ] `DiqitLogger.exportLogsForTrace(traceId)` returns a formatted text string containing only log lines matching the specified `traceId`.
- [ ] Unit tests in `test/src/diqit_logging_test.dart` verify filtering accuracy across interleaved log events.

## Blocked by

- Issue 2: Integrate Active `TraceZone` ID into `DiqitLogger` Output Printers ([0002-log-formatting-zone-integration.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/issues/0002-log-formatting-zone-integration.md))
