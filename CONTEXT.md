# Diqit Logging Context

Provides structured, zone-based diagnostic logging and distributed correlation across mobile POS applications.

A log line answers three orthogonal questions — **where**, **which flow**, and **what data**:

| Question | Concept | Example |
|----------|---------|---------|
| Where (layer)? | LogTag | `NETWORK`, `BLOC`, `UI` |
| Which flow? | TraceId | `#order-12345` |
| What entity? | Loggable | `{uuid: abc, total: $45}` |

## Language

**DiqitLogger**:
The central logging entrypoint that unifies console printing, file logging, and trace correlation across the application lifecycle.
_Avoid_: Logger instance, Log manager, Print service

**LoggerConfig**:
The configuration blueprint governing log levels, tag filters, file output paths, and visual formatting rules for the logger.
_Avoid_: Log options, Printer settings, Logger params

**LogTag**:
A categorization label identifying the architectural layer or subsystem producing the log (e.g. `NETWORK`, `BLOC`, `UI`, `MQTT`). Used for coarse filtering — show me only network logs, hide all UI logs. Orthogonal to TraceId (which answers "which operation flow").
_Avoid_: Log category, Event module, Domain tag

**TraceId**:
A typed unique identifier for tracing a logical business operation across async boundaries and network hops. Created via factories: `TraceId.manual(group, num)` for explicit external IDs, `TraceId.auto(group)` for auto-incrementing per-group counters, or `TraceId.global()` for a shared counter. Supports suffix chaining (`withSuffix`) for retries and fallback paths. Orthogonal to LogTag (which answers "which layer").
_Avoid_: Correlation ID, Request UUID, Trace string

**ZoneTrace**:
An execution context powered by Dart `Zone` that carries a stack of `TraceId` values, enabling nested traces and automatic propagation across futures, streams, and event boundaries. Logs within a traced zone automatically inherit the current trace stack without manual parameter passing. Also carries source identity for cross-app attribution and provides Socket.IO metadata transport via `injectTraceId` / `extractTraceId`.
_Avoid_: TraceZone, Logger scope, Request context, Thread local

**Loggable**:
A mixin protocol enabling domain entities to define their structured log representation via `toLoggableMap()`. DiqitLogger automatically detects and formats objects implementing this protocol, producing readable key-value output instead of opaque `toString()` results.
_Avoid_: Serializable, LoggableObject, DebugPrintable

**TypeConverter**:
A registry-based formatting mechanism for third-party types (DateTime, Duration, Uri) that cannot implement the Loggable mixin. Registered via `DiqitLogger.registerConverter<T>()`, converters provide human-readable string representation for common types without modifying their source code.
_Avoid_: Type formatter, Custom serializer, Value printer

**Log History**:
An in-memory rolling buffer of formatted log events maintained for real-time inspection and on-device debugging. Supports filtering by trace ID via `getLogHistoryForTrace`.
_Avoid_: Log cache, Memory store, Event queue
