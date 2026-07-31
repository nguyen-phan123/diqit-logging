# Issue 2: Integrate Active `TraceZone` ID into `DiqitLogger` Output Printers

## Parent

PRD: Zone-based Tracing (`TraceZone`) for Mobile POS Systems ([0001-zone-based-tracing-prd.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/prd/0001-zone-based-tracing-prd.md))

## What to build

Update `DiqitLogger` and underlying log printers (`DiqitPrettyPrinter`, `AlignedPrettyPrinter`) to implicitly read `TraceZone.currentTraceId`. When a log statement is executed inside an active `TraceZone`, automatically append `[trace:t-xxxx]` to the console and file log outputs.

## Acceptance criteria

- [ ] `DiqitLogger.i('Message')` implicitly reads `TraceZone.currentTraceId` without explicit developer parameters.
- [ ] Log output lines include `[trace:t-a1b2c3d4]` tag prefix when executed within an active trace zone.
- [ ] Log lines executed outside any `TraceZone` omit the trace tag cleanly without formatting errors.
- [ ] Unit tests verify formatted output for both trace-active and non-trace log events.

## Blocked by

- Issue 1: Implement `TraceZone` Core Utility with Async Context Propagation and Error Interception ([0001-tracezone-core-propagation.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/issues/0001-tracezone-core-propagation.md))
