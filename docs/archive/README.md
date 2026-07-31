# Archived Documentation & Specifications

This directory contains historical specifications, PRDs, task issues, and implementation plans that have been completed or superseded by newer architectural decisions.

## Archived Items Index

### PRDs (Product Requirement Documents)
- [0001-zone-based-tracing-prd.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/archive/prd/0001-zone-based-tracing-prd.md)
  - **Archived Date**: 2026-07-31
  - **Reason**: Original `TraceZone` specification (flat string trace IDs, single-level). Superseded by typed `TraceId` and stack-based `ZoneTrace` in [0002-typed-trace-id-and-stack-nesting.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/adr/0002-typed-trace-id-and-stack-nesting.md) and active PRD [trace-id-zone-propagation.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/prd/trace-id-zone-propagation.md).

### Issues & Implementation Tasks
- [0001-tracezone-core-propagation.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/archive/issues/0001-tracezone-core-propagation.md)
- [0002-log-formatting-zone-integration.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/archive/issues/0002-log-formatting-zone-integration.md)
- [0003-trace-history-filtering-export-api.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/archive/issues/0003-trace-history-filtering-export-api.md)
- [0004-socket-envelope-propagation-helper.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/archive/issues/0004-socket-envelope-propagation-helper.md)
  - **Archived Date**: 2026-07-31
  - **Reason**: Task breakdowns for initial `TraceZone` implementation. Implemented and superseded by `ZoneTrace` refactor.

### Refactoring Plans
- [PLAN-refactor-diqit-logger.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/archive/plans/PLAN-refactor-diqit-logger.md)
  - **Archived Date**: 2026-07-31
  - **Reason**: Completed execution plan for `DiqitLogger` root facade & scoped logger delegation ([ADR 0005](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/adr/0005-diqit-logger-root-facade-and-scoped-delegation.md)).
- [PLAN-rewrite-readme.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/docs/archive/plans/PLAN-rewrite-readme.md)
  - **Archived Date**: 2026-07-31
  - **Reason**: Completed plan for updating package [README.md](file:///Users/diqit/Documents/GitHub/phj-sprint-PSV-S03/packages/diqit-logging/README.md).
