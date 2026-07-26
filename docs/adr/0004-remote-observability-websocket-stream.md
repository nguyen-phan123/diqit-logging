# 0004: Remote Observability via WebSocket Stream

- **Status**: Accepted
- **Date**: 2026-07-26
- **Authors**: Platform Team

## Context

DiqitLogger currently outputs to **local surfaces only**: console (colored terminal), file (rotating log), and in-memory buffer (1000 events for history queries). When a developer needs to observe logs from a running app on a physical POS device (iPad, Android tablet), they must physically access the device screen or pull log files via USB/adb. There is no way to **remotely observe** log output in real time during development and debugging.

**Problem:** POS apps run on touchscreen devices in a store environment. Developer's laptop is elsewhere on the same WiFi network. Without remote log streaming, debugging physical device issues requires either:
1. Standing at the device reading tiny console text
2. Pulling log files after the fact (post-mortem only)
3. Adding debug-specific UI panels (waste of dev time)

## Decision

We add a **WebSocket-based log output** that streams formatted log lines from the POS app to any connected client. The architecture is deliberately minimal:

| Aspect | Decision |
|--------|----------|
| Transport | WebSocket (plain `ws://`, no TLS) |
| Port | Configurable, default 9229 (Chrome DevTools convention) |
| Format | Plain text — `DLogMessage.toString()` output, identical to console |
| Buffer | Dump full Log History (1000 events) on client connect |
| Receiver | Any WebSocket client (`websocat`, `wscat`, browser) |
| Lifecycle | Starts with `enableNetworkLogging: true` in LoggerConfig |

**Why not JSON/NDJSON:** The initial use case is human-readable inspection. Plain text is zero-effort for the receiver (`websocat ws://...` with no flags). Structured format for AI agents is deferred to a future phase.

**Why not HTTP:** WebSocket provides persistent bidirectional streaming suitable for real-time tailing. HTTP polling would add latency and waste bandwidth.

**Why not Socket.IO:** The existing Socket.IO infrastructure in POS apps serves business operations (order sync, payment confirmation). Log streaming is a separate concern that should not compete with business message throughput. A dedicated plain WebSocket server keeps the logging channel isolated.

## Architecture

```
POS Device (192.168.1.5)               Developer Laptop (192.168.1.100)
┌──────────────────────────┐           ┌─────────────────┐
│ DiqitLogger              │           │  websocat        │
│  ├─ MemoryOutput (1K)    │──WS─────▶│  ws://.5:9229    │
│  ├─ ConsoleOutput        │           └─────────────────┘
│  ├─ FileOutput (opt)     │
│  └─ NetworkOutput :9229  │
└──────────────────────────┘
```

### Module: NetworkOutput

`NetworkOutput extends LogOutput` — plugs into the existing `MultiOutput` chain in `DiqitLogger._createLoggerInstance()`. Follows the same pattern as `AdvancedFileOutput` and `ConsoleOutput`.

Key behaviors:
- **Server lifecycle**: Started during `initialize()` / `updateConfig()`, stopped on config change or shutdown
- **Buffer dump**: On WebSocket connect, reads `_globalBuffer.buffer` (lazy getter, captures current state) and sends all lines
- **Multi-client**: Supports multiple simultaneous connections; each receives the same stream
- **Error isolation**: Port-in-use errors are caught and logged to console; logger continues functioning normally without network output
- **Off by default**: `LoggerConfig.enableNetworkLogging` defaults to `false`; developers opt in explicitly

### Configuration

```dart
// LoggerConfig gains two fields:
class LoggerConfig {
  final bool enableNetworkLogging;  // default: false
  final int networkPort;            // default: 9229
}
```

Both are immutable; use `copyWith()` for runtime changes. The development factory preset keeps `enableNetworkLogging: false` to avoid opening a port in production.

## Consequences

### Positive
- **Zero receiver setup** — `brew install websocat` on macOS, `websocat ws://<ip>:9229`
- **Familiar output** — same formatted lines as console (prefix, source, tag, path, traceId, context, message, data)
- **Immediate context** — buffer dump on connect provides last 1000 events without waiting
- **Near-zero overhead when idle** — no bytes sent, only `HttpServer` listening; `output()` skips when no clients connected
- **Clean seam** — plugs into existing `LogOutput` interface; zero changes to `_log()` or printer pipeline

### Negative
- **No authentication** — any device on the same network can connect. Acceptable for development; production should keep `enableNetworkLogging: false`
- **No TLS** — plain text over WiFi. Acceptable for local network; remote debugging over internet would require encryption (out of scope)
- **Per-device only** — each POS app serves its own stream; no aggregation across devices. Multi-device aggregation is a separate concern for future phases

### Neutral
- **Plain text format** — human-readable but not parseable by tools. JSON/NDJSON deferred to future AI-agent-readable phase
- **Single port per device** — multiple apps on the same device must use different ports (configurable via `networkPort`)

## Alternatives Considered

### Alternative 1: JSON/NDJSON from day one
**Pros:** Machine-parseable, AI-ready  
**Cons:** 
- Forces receiver tooling (`jq`, custom parser) even for quick human inspection
- Adds format complexity before validating the streaming concept
- `DLogMessage.toString()` is already a well-defined, stable format

**Verdict:** Rejected. Start simple, add structure when needed.

### Alternative 2: HTTP endpoint for log snapshot
**Pros:** Stateless, cacheable, works with `curl`  
**Cons:** 
- No real-time tailing without polling
- Adds latency between log emission and observation
- WebSocket is the native protocol for streaming data

**Verdict:** Rejected. Streaming is the primary use case.

### Alternative 3: Integrate with existing Socket.IO infrastructure
**Pros:** Reuses existing connection, no new port  
**Cons:** 
- Couples diagnostic logging to business message channel
- Log volume could degrade Socket.IO performance
- Harder to isolate and debug independently

**Verdict:** Rejected. Separate channel for separate concern.

## Related ADRs
- [0001: Zone-based Tracing](./0001-zone-based-tracing.md) — Socket.IO metadata transport for trace correlation
- [0003: Structured Object Logging](./0003-structured-logging-and-namespace-hierarchy.md) — Loggable/TypeConverter producing the formatted output that NetworkOutput streams

## References
- [websocat](https://github.com/vi/websocat) — Universal WebSocket client
- [Dart HttpServer](https://api.dart.dev/stable/dart-io/HttpServer-class.html) — Underlying server
