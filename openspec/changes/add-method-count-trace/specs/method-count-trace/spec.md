## ADDED Requirements

### Requirement: Custom Stack Trace Depth for Detailed Loggers
The system SHALL allow developers to specify a custom method count (stack trace depth) for `info`, `warning`, `trace`, `debug`, and `fatal` loggers via a `countMethod` parameter.

#### Scenario: User provides a custom method count
- **WHEN** a developer calls `DiqitLogger.info(..., countMethod: 5)`
- **THEN** the logger prints exactly 5 frames of the stack trace.

#### Scenario: User omits the custom method count
- **WHEN** a developer calls `DiqitLogger.info(...)` without `countMethod`
- **THEN** the logger prints the default number of stack trace frames defined by the internal `_tracePrinter`.
