# Issue 4: Document and Provide Helper for Socket.IO Transport Envelope Propagation

## Parent

PRD: Zone-based Tracing (`TraceZone`) for Mobile POS Systems ([0001-zone-based-tracing-prd.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/prd/0001-zone-based-tracing-prd.md))

## What to build

Provide helper functions and documentation for wrapping Socket.IO event listener callbacks in mobile POS applications with `TraceZone.runInTraceZone(meta.traceId, callback)` to achieve end-to-end cross-app log correlation across KDS, OT, Dispatch, and Customer Display apps.

## Acceptance criteria

- [ ] Helper function `TraceEnvelope.extractTraceId(payload)` cleanly parses `meta.traceId` from standard payload envelopes `{ "meta": { "traceId": "..." }, "data": { ... } }`.
- [ ] Helper function `TraceEnvelope.injectTraceId(payload, traceId)` attaches active or new `traceId` to outgoing Socket event payloads.
- [ ] Documentation and example code in README.md demonstrate wrapping Socket.IO event handlers.
- [ ] Unit tests verify payload envelope extraction and injection.

## Blocked by

- Issue 1: Implement `TraceZone` Core Utility with Async Context Propagation and Error Interception ([0001-tracezone-core-propagation.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/issues/0001-tracezone-core-propagation.md))
