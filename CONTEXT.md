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

**Loggable**:
A mixin protocol enabling domain entities to define their structured log representation via `toLoggableMap()`. DiqitLogger automatically detects and formats objects implementing this protocol, producing readable key-value output instead of opaque `toString()` results.
_Avoid_: Serializable, LoggableObject, DebugPrintable
_Status_: Approved in ADR-0003, pending implementation

**TypeConverter**:
A registry-based formatting mechanism for third-party types (DateTime, Duration, Uri) that cannot implement the Loggable mixin. Registered via `DiqitLogger.registerConverter<T>()`, converters provide human-readable string representation for common types without modifying their source code.
_Avoid_: Type formatter, Custom serializer, Value printer
_Status_: Approved in ADR-0003, pending implementation
