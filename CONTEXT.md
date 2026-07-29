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
The central logging entrypoint that unifies console printing, file logging, and trace correlation. Acts as a static facade delegating to the single source of truth `root` instance. Supports lightweight scoped/child loggers (`DiqitLogger('namespace')` or `DiqitLogger.scoped('namespace')`) that carry a path header while dynamically delegating configuration, type converters, and output sinks to `root`.
_Avoid_: Logger instance, Log manager, Print service


**LoggerConfig**:
The configuration blueprint governing log levels, tag filters, file output paths, and visual formatting rules for the logger. Uses `appName` as the canonical application identity (deprecates `prefixMessage`).
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

**NetworkOutput**:
A bi-directional `LogOutput` implementation that starts an internal WebSocket server on a configurable port, streaming formatted log lines to connected clients and accepting Log Commands from them. On connect, dumps the full Log History (up to 1000 events) then streams new events live. Designed for remote debugging — a developer connects with the `diqit-socket-logger` TUI or `websocat ws://<device-ip>:9229` to observe logs in real time without physical device access. Server-side only; enabled via `LoggerConfig.enableNetworkLogging`.
_Avoid_: WebSocket output, Remote logger, Socket stream

**Log Command**:
A plain-text directive sent from a WebSocket CLI client (e.g. `diqit-socket-logger`) to NetworkOutput requesting a server-side action. Recognized by a `!` prefix (e.g. `!clear`, `!copy`, `!help`). Processed inline alongside log streaming on the same socket connection — no separate control channel needed.
_Avoid_: WebSocket command, Control message, Remote instruction

**Clear (Log History)**:
The action of resetting the in-memory Log History buffer to empty, discarding all buffered events. A global operation — all connected clients see the buffer drain on next status dump. Triggered via the `!clear` Log Command.
_Avoid_: Flush buffer, Reset history, Purge logs

**Copy (Export to Client)**:
The action of sending a formatted text dump of the current Log History to the requesting WebSocket client, delimited with markers so the developer can capture it from their terminal and paste into external tools. Triggered via the `!copy` Log Command. Not an OS clipboard operation — the server emits the text; the client captures it.
_Avoid_: Clipboard, Paste buffer, Snapshot
