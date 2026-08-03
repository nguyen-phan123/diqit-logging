# Diqit Logging Context

Provides structured, zone-based diagnostic logging and distributed correlation across mobile POS applications.

A log line answers four orthogonal questions — **where**, **which module**, **which flow**, and **what data**:

| Question | Concept | Example |
|----------|---------|---------|
| Where (layer)? | LogTag | `NETWORK`, `BLOC`, `UI` |
| Which module? | Scoped Path | `kds/order_grid` |
| Which flow? | TraceId | `#order-12345` |
| What entity? | Loggable | `{uuid: abc, total: $45}` |

## Language

### Core Facade & Configuration

**DiqitLogger**:
A static facade over a singleton root logger instance that manages centralized configuration and log dispatch across mobile POS apps.
_Avoid_: Logger instance, Log manager, Print service

**Scoped Logger**:
A lightweight child logger instance bound to a specific namespace path that delegates configuration, converters, and outputs dynamically to the root logger.
_Avoid_: Child logger, Sub-logger, Local logger

**Scoped Path**:
A hierarchical namespace string (e.g. `kds/order_grid`) identifying the feature module or component producing a log event.
_Avoid_: Namespace header, Log path, Category path, Subsystem string

**LoggerConfig**:
An immutable configuration blueprint governing log levels, tag filters, file outputs, network streaming, and visual formatting. Uses `appName` as the canonical application identity.
_Avoid_: Log options, Printer settings, Logger params

**LogSinkPipeline**:
An internal deep module that manages the initialization, configuration updates, and lifecycle for all log output sinks (Console, File, Network WebSocket, Memory Buffer).
_Avoid_: Output manager, Sink handler, Multi-output controller


### Architectural Taxonomy & Tracing

**LogTag**:
An architectural layer label (e.g. `NETWORK`, `BLOC`, `UI`, `MQTT`) used for coarse log filtering across application layers.
_Avoid_: Log category, Event module, Domain tag

**TraceId**:
A typed unique identifier for correlating a logical business operation across async boundaries and network hops.
_Avoid_: Correlation ID, Request UUID, Trace string

**ZoneTrace**:
A Dart `Zone` execution context carrying a stack of `TraceId` values for nested trace propagation across futures, streams, and socket boundaries.
_Avoid_: TraceZone, Logger scope, Request context, Thread local

### Structured Data Protocol

**Loggable**:
A mixin protocol enabling domain entities to define a key-value map representation for structured log formatting.
_Avoid_: Serializable, LoggableObject, DebugPrintable

**TypeConverter**:
A registered formatting callback for third-party types (e.g. DateTime, Duration, Uri) that cannot implement the Loggable mixin.
_Avoid_: Type formatter, Custom serializer, Value printer

**DLogMessage**:
The internal log envelope carrying a raw log string along with its tag, trace ID, path, context metadata, and structured data payload.
_Avoid_: Log payload, Log record, Event envelope

### Console Rendering Engine

**RowPrinter**:
The canonical console printer that formats log events into a single-line header followed by indented payload lines using composable elements.
_Avoid_: Shorthand printer, Line printer, Pretty printer, DShorthandPrinter

**LogElement**:
A composable visual building block evaluated against a rendering context to construct specific components of a console log line.
_Avoid_: Log chunk, Printer segment, Format component

**LogFunctionElement**:
A `LogElement` implementation in `diqit-logging` that extracts and renders caller function/method details in `{ClassName.methodName}` or `{functionName}` format into the console log header, positioned between `LogPathElement` and `LogTraceIdElement`.

### Remote Observability & WebSockets

**NetworkOutput**:
A `LogOutput` implementation that runs a local WebSocket server to stream log events and accept interactive Log Commands.
_Avoid_: WebSocket output, Remote logger, Socket stream

**Log Command**:
A text directive (e.g. `!clear`, `!copy`, `!help`) sent from a WebSocket client to NetworkOutput to request a server-side action.
_Avoid_: WebSocket command, Control message, Remote instruction

**Log History**:
An in-memory rolling buffer of formatted log events retained for real-time inspection, filtering, and WebSocket dumps.
_Avoid_: Log cache, Memory store, Event queue

**Clear (Log History)**:
The action of emptying the in-memory Log History buffer across all connected clients via `!clear`.
_Avoid_: Flush buffer, Reset history, Purge logs

**Copy (Export to Client)**:
The action of streaming a delimited dump of the current Log History to a requesting WebSocket client via `!copy`.
_Avoid_: Clipboard, Paste buffer, Snapshot

