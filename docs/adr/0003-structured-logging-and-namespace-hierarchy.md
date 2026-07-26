# 0003: Structured Logging and Namespace Hierarchy

- **Status**: Proposed
- **Date**: 2026-07-26
- **Authors**: Platform Team
- **Inspired by**: [team_logger](https://github.com/vi-k/team_logger) architecture

## Context

DiqitLogger currently provides a **singleton-based logging API** with good primitives (trace zones, tag filtering, dual printers). However, three gaps emerge in a **monorepo with 5 Flutter apps** (KDS, OT Master, OT Client, Dispatch, Customer Display) sharing cross-device trace flows:

### 1. **Complex objects log poorly**

```dart
// Current: objects dump as toString() or require manual formatting
final order = OrderEntity(uuid: 'abc-123', total: 45.50, items: [...]);
DiqitLogger.i('Order created: $order');
// Output: Order created: Instance of 'OrderEntity'

// Workaround: manual serialization
DiqitLogger.i('Order created: uuid=${order.uuid}, total=${order.total}');
// Verbose, inconsistent across codebase
```

**Problem:** No standard way to log domain entities (OrderEntity, KdsBatchesEntity, SocketEnvelope) with readable structure.

### 2. **Flat namespace prevents filtering by app/feature**

```dart
// All logs share same DiqitLogger singleton
DiqitLogger.i('Processing batch', tag: LogTag.kds);  // KDS app
DiqitLogger.i('Creating order', tag: LogTag.order);  // OT app
DiqitLogger.i('Dispatching driver', tag: LogTag.dispatch); // Dispatch app
```

**Problem:** 
- Cannot filter logs by **app hierarchy** (e.g., "show all OT logs" vs "show only OT/order/payment logs")
- LogTag system is flat — no parent/child relationship
- In production, logs from 5 apps on same device mix together without clear separation

### 3. **Output format is fixed**

```dart
// Development: want verbose, colorful logs with stack traces
final devConfig = LoggerConfig.development();

// Production: want compact, JSON-ready logs for aggregation
final prodConfig = LoggerConfig.production();
```

**Problem:** 
- DShorthandPrinter and DPrettyPrinter are hardcoded
- Cannot customize layout (e.g., add sequence numbers, reorder fields)
- Cannot switch themes at runtime (e.g., "activate payment logs, dim everything else")

## Decision

We adopt **6 features** inspired by `team_logger`, implemented as **additive layers** over DiqitLogger singleton to preserve backward compatibility:

### Feature Set (by priority)

| Priority | Feature | Status | Effort |
|----------|---------|--------|--------|
| **P0** | Loggable Mixin | Proposed | Low (1-2 days) |
| **P1** | Namespace Loggers | Proposed | Medium (2-3 days) |
| **P1** | Custom Themes/Layouts | Proposed | Medium (3-4 days) |
| **P2** | Type Converters | Proposed | Low (1 day) |
| **P2** | BBCode Formatting | Proposed | Medium (2-3 days) |
| **P3** | Active/Inactive Modes | Proposed | Low (1 day) |

---

## Architecture Design

### 1. Loggable Mixin (P0)

**Goal:** Standard protocol for logging complex objects.

```dart
// lib/src/logger/loggable.dart
mixin Loggable {
  /// Convert object to loggable representation.
  /// Keys should be human-readable field names.
  Map<String, dynamic> toLoggableMap();
}

// Usage in domain layer
class OrderEntity with Loggable {
  final String uuid;
  final double total;
  final List<OrderDetailEntity> orderDetails;

  @override
  Map<String, dynamic> toLoggableMap() => {
    'uuid': uuid,
    'total': '\$${total.toStringAsFixed(2)}',
    'items_count': orderDetails.length,
    'status': status.name,
  };
}

// DiqitLogger auto-formats Loggable objects
DiqitLogger.i('Order created', data: orderEntity);
// Output: [10:30:45] ℹ [OTM] [ORDER] Order created
//         Data: {uuid: abc-123, total: $45.50, items_count: 3, status: pending}
```

**Implementation:**
- Add optional `data` parameter to all log methods
- Printer detects `Loggable` mixin via `is Loggable`
- Falls back to `.toString()` for non-Loggable objects

**Breaking:** None (additive)

---

### 2. Namespace Loggers (P1)

**Goal:** Hierarchical logger organization without breaking singleton pattern.

```dart
// lib/src/logger/namespaced_logger.dart
class NamespacedLogger {
  final String path;
  final DiqitLogger _backend;
  
  NamespacedLogger(this.path, [DiqitLogger? backend])
      : _backend = backend ?? DiqitLogger.instance;
  
  /// Create child logger: parent/child
  NamespacedLogger child(String name) {
    final separator = path.isEmpty ? '' : '/';
    return NamespacedLogger('$path$separator$name', _backend);
  }
  
  /// Log methods delegate to backend with path prefix
  void i(String msg, {Object? data, LogTag tag = LogTag.none}) {
    final prefixedMsg = path.isEmpty ? msg : '[$path] $msg';
    _backend.i(prefixedMsg, data: data, tag: tag);
  }
  
  // ... d(), w(), e(), etc.
}

// Usage in apps
// lib/main.dart (OT Master app)
final otmLog = NamespacedLogger('OTM');
final orderLog = otmLog.child('order');
final paymentLog = orderLog.child('payment');

paymentLog.i('Charge succeeded', data: chargeResult);
// Output: [10:30:45] ℹ [OTM] [PAYMENT] [OTM/order/payment] Charge succeeded
```

**Design choices:**
- **Wrapper pattern** — NamespacedLogger wraps singleton, doesn't replace it
- **Opt-in** — existing code using `DiqitLogger.i()` continues to work
- **Path in message** — namespace appears in log content, not as separate metadata (simplifies grep/filtering)

**Breaking:** None (opt-in wrapper)

---

### 3. Custom Themes/Layouts (P1)

**Goal:** Pluggable formatters for dev vs prod, with runtime theme switching.

```dart
// lib/src/logger/theme.dart
abstract class LogTheme {
  String formatTimestamp(DateTime time);
  String formatLevel(Level level);
  String formatTrace(TraceId? trace);
  String formatTag(LogTag tag);
  String formatMessage(String msg);
  String formatData(Object? data);
}

// lib/src/logger/themes/dev_theme.dart
class DevTheme implements LogTheme {
  @override
  String formatTimestamp(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '[$h:$m:$s.$ms]';
  }
  
  @override
  String formatLevel(Level level) {
    // ANSI colors for dev console
    const colors = {
      Level.trace: '\x1B[90m🔍',    // dim gray
      Level.debug: '\x1B[36mℹ',     // cyan
      Level.info: '\x1B[32m✓',      // green
      Level.warning: '\x1B[33m⚠',   // yellow
      Level.error: '\x1B[31m✗',     // red
      Level.fatal: '\x1B[35m💀',    // magenta
    };
    return '${colors[level] ?? 'ℹ'}\x1B[0m';
  }
  
  // ... other formatters with colors, emojis
}

// lib/src/logger/themes/prod_theme.dart
class ProdTheme implements LogTheme {
  @override
  String formatTimestamp(DateTime time) => time.toIso8601String();
  
  @override
  String formatLevel(Level level) => level.name.toUpperCase();
  
  // JSON-friendly, no colors, compact
}

// Usage
final config = LoggerConfig(
  theme: DevTheme(),  // or ProdTheme()
  enableConsoleLogging: true,
);
await DiqitLogger.initialize(config);
```

**Design choices:**
- **Strategy pattern** — theme is pluggable via LoggerConfig
- **Backward compat** — if no theme specified, use current DShorthandPrinter logic as default
- **Runtime switching** — `DiqitLogger.updateConfig(config.copyWith(theme: ProdTheme()))` changes theme on the fly

**Breaking:** Potential if we refactor DShorthandPrinter/DPrettyPrinter to use theme internally

---

### 4. Type Converters (P2)

**Goal:** Format third-party classes that can't implement `Loggable`.

```dart
// lib/src/logger/type_converter.dart
typedef TypeConverter<T> = String Function(T value);

class TypeConverterRegistry {
  final Map<Type, TypeConverter> _converters = {};
  
  void register<T>(TypeConverter<T> converter) {
    _converters[T] = converter;
  }
  
  String? convert(Object value) {
    final converter = _converters[value.runtimeType];
    return converter?.call(value);
  }
}

// Usage
DiqitLogger.registerConverter<DateTime>((dt) => dt.toIso8601String());
DiqitLogger.registerConverter<Duration>((d) => '${d.inSeconds}s');

DiqitLogger.i('Event scheduled', data: DateTime.now());
// Auto-converts: Event scheduled
//                Data: 2026-07-26T10:30:45.123Z
```

**Implementation:**
- Global registry in DiqitLogger singleton
- Printer checks converters before falling back to `.toString()`
- Lookup order: 1) Loggable, 2) TypeConverter, 3) toString()

**Breaking:** None (additive)

---

### 5. BBCode Formatting (P2)

**Goal:** Inline text styling for console logs.

```dart
DiqitLogger.i('[success]Payment succeeded[/success] for order [b]#12345[/b]');
// Console output: Payment succeeded (green) for order #12345 (bold)
```

**Supported tags:**
```dart
[b]bold[/b]           → ANSI bold
[i]italic[/i]         → ANSI italic
[u]underline[/u]      → ANSI underline
[success]...[/success] → green
[error]...[/error]     → red
[warning]...[/warning] → yellow
[dim]...[/dim]         → gray
```

**Implementation:**
- BBCode parser in `lib/src/logger/bbcode_parser.dart`
- Theme system provides ANSI mapping
- Parse message string before output, replace tags with ANSI codes

**Design choice:**
- **Opt-in** — only parse if message contains `[` character (performance)
- **Prod-safe** — ProdTheme strips BBCode tags instead of converting to ANSI

**Breaking:** None (additive)

---

### 6. Active/Inactive Modes (P3)

**Goal:** Visual separation between "current focus" and "background noise".

```dart
// In multi-logger scenario
final orderLog = otmLog.child('order');
final paymentLog = otmLog.child('payment');

// Debugging payment flow specifically
paymentLog.activate();   // Switch to high-contrast theme
orderLog.deactivate();   // Switch to low-contrast theme

// Logs from paymentLog: bright colors, full detail
// Logs from orderLog: dim gray, minimal detail
```

**Implementation:**
- Each NamespacedLogger tracks `isActive` state
- Theme has 2 variants: `activeFormat()` and `inactiveFormat()`
- Printer selects variant based on logger state

**Breaking:** None (additive, requires namespace loggers)

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- **Ticket 1.1:** Loggable mixin + printer integration (P0)
- **Ticket 1.2:** Add `data` parameter to all log methods

**Deliverable:** Can log domain entities with structured output

---

### Phase 2: Organization (Week 2)
- **Ticket 2.1:** NamespacedLogger wrapper (P1)
- **Ticket 2.2:** LogTheme interface + DevTheme/ProdTheme (P1)
- **Ticket 2.3:** Refactor printers to use theme system

**Deliverable:** Can organize logs by hierarchy, switch themes at runtime

---

### Phase 3: Enhancement (Week 3)
- **Ticket 3.1:** TypeConverterRegistry (P2)
- **Ticket 3.2:** BBCode parser + ANSI mapping (P2)

**Deliverable:** Can format third-party types, use inline styling

---

### Phase 4: Polish (Week 4)
- **Ticket 4.1:** Active/inactive mode for NamespacedLogger (P3)
- **Ticket 4.2:** Documentation + migration guide

**Deliverable:** Full feature parity with team_logger patterns

---

## Consequences

### Positive
- **Structured logging** — domain entities log readably without manual formatting
- **Hierarchical organization** — filter logs by app/feature hierarchy in monorepo
- **Flexible formatting** — dev vs prod themes, runtime switching
- **Backward compatible** — all features are opt-in wrappers over singleton
- **Extensible** — type converters and BBCode are open for customization

### Negative
- **Increased complexity** — 6 new concepts vs current simple singleton API
- **Migration effort** — existing code continues to work, but won't get new features until migrated to NamespacedLogger
- **Performance overhead** — BBCode parsing, theme formatting add microseconds per log (acceptable for dev, should profile for prod)

### Neutral
- **Not a full distributed tracing solution** — this ADR covers *local* log formatting and organization. Cross-device trace correlation (via TraceEnvelope) is already handled by ADR 0001/0002.
- **team_logger not adopted directly** — we cherry-pick patterns, not the library itself, to maintain control over singleton architecture and monorepo integration.

---

## Alternatives Considered

### Alternative 1: Adopt team_logger directly
**Pros:** Battle-tested, full feature set  
**Cons:** 
- Requires replacing DiqitLogger singleton (breaking change)
- Loses existing TraceEnvelope/Socket.IO integration
- External dependency vs in-house control

**Verdict:** Rejected. Too disruptive for incremental value gain.

---

### Alternative 2: Keep current system, add only Loggable
**Pros:** Minimal change, quick win  
**Cons:** 
- Doesn't solve namespace problem (monorepo log filtering)
- Doesn't solve theme problem (dev vs prod format)

**Verdict:** Rejected. Solves 1/3 of the problem.

---

### Alternative 3: Use OpenTelemetry SDK
**Pros:** Industry standard, distributed tracing, APM integration  
**Cons:** 
- Heavy dependency (~500KB+ in Flutter)
- Overkill for local logging use case
- Requires external collector/backend

**Verdict:** Rejected for now. Revisit when we need APM integration (separate ADR).

---

## Related ADRs
- [0001: Zone-based Tracing](./0001-zone-based-tracing.md) — TraceZone foundation
- [0002: Typed TraceId and Stack-based Nesting](./0002-typed-trace-id-and-stack-nesting.md) — TraceId value object

---

## References
- [team_logger GitHub](https://github.com/vi-k/team_logger) — Inspiration source
- [OpenTelemetry Dart](https://opentelemetry.io/docs/languages/dart/) — Considered alternative
- [Dart Zone API](https://api.dart.dev/stable/dart-async/Zone-class.html) — Underlying trace propagation mechanism
