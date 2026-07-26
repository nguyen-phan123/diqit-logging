# Diqit Logging Context

Provides structured, zone-based diagnostic logging and distributed correlation across mobile POS applications.

## Language

**DiqitLogger**:
The central logging entrypoint that unifies console printing, file logging, and trace correlation across the application lifecycle.
_Avoid_: Logger instance, Log manager, Print service

**LoggerConfig**:
The configuration blueprint governing log levels, tag filters, file output paths, and visual formatting rules for the logger.
_Avoid_: Log options, Printer settings, Logger params

**TraceId**:
A typed unique identifier for tracing a logical operation across async boundaries and network hops. Created via factories: `TraceId.manual(group, num)` for explicit external IDs, `TraceId.auto(group)` for auto-incrementing per-group counters, or `TraceId.global()` for a shared counter. Supports suffix chaining (`withSuffix`) for retries and fallback paths.
_Avoid_: Correlation ID, Request UUID, Trace string

**ZoneTrace**:
An execution context powered by Dart `Zone` that carries a stack of `TraceId` values, enabling nested traces and automatic propagation across futures, streams, and event boundaries. Logs within a traced zone automatically inherit the current trace stack without manual parameter passing.
_Avoid_: TraceZone, Logger scope, Request context, Thread local

**Trace Envelope**:
The standardized Socket.IO event transport wrapper carrying metadata (including `traceId` and source application) alongside the event payload across mobile POS apps. Uses `TraceEnvelope.injectTraceId` / `extractTraceId` with `TraceId` instances, serializing to string for wire transport.
_Avoid_: Custom payload header, Trace DTO

**LogTag**:
A categorization label assigned to log statements to identify the subsystem or feature module producing the event.
_Avoid_: Log category, Event module, Channel

**Log History**:
An in-memory rolling buffer of formatted log events maintained for real-time inspection and on-device debugging. Supports filtering by trace ID via `getLogHistoryForTrace`.
_Avoid_: Log cache, Memory store, Event queue

**Loggable** (Proposed - ADR 0003):
A mixin protocol enabling domain entities to define their structured log representation via `toLoggableMap()`. DiqitLogger automatically detects and formats objects implementing this protocol, producing readable key-value output instead of opaque `toString()` results.
_Avoid_: Serializable, LoggableObject, DebugPrintable

**NamespacedLogger** (Proposed - ADR 0003):
A hierarchical logger wrapper organizing logs by path (e.g., `OTM/order/payment`) without replacing the DiqitLogger singleton. Creates parent-child relationships via `child(name)` and prefixes all log messages with the full path for filtering in monorepo environments.
_Avoid_: Scoped logger, Child logger, Logger hierarchy

**LogTheme** (Proposed - ADR 0003):
A pluggable formatter strategy defining how timestamps, levels, traces, tags, and messages render in log output. Enables runtime switching between development themes (colorful, verbose) and production themes (compact, JSON-ready) via `LoggerConfig`.
_Avoid_: Log format, Printer style, Output template
