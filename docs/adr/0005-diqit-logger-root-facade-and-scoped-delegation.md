# 0005: DiqitLogger Root Facade & Scoped Logger Delegation Architecture

- **Status**: Accepted
- **Date**: 2026-07-29
- **Authors**: Platform Team

## Context

In complex multi-package monorepo applications (KDS, OT, Dispatch), different submodules and layers require log path namespacing (e.g. `kds/order_grid` vs `payment/gateway`) while maintaining a single, consistent runtime configuration across the entire app.

Initially, `DiqitLogger` allowed creating child loggers via `_child(path)`, but child loggers maintained independent `_config` and `_initialized` state checks. This caused configuration drift when `DiqitLogger.updateConfig()` or `registerConverter<T>()` was called on the static logger: previously created child loggers did not reflect updated log levels, outputs, or converters.

## Decision

We establish `DiqitLogger` as a **Static Facade over a Singleton Root Instance** with **Dynamic Child Delegation**:

### 1. `DiqitLogger.root` is the Single Source of Truth
- `DiqitLogger.root` manages all shared state: `LoggerConfig`, `TypeConverterRegistry`, `MemoryOutput` buffer, `AdvancedFileOutput`, and `NetworkOutput`.
- All static methods (`DiqitLogger.i()`, `DiqitLogger.initialize()`, `DiqitLogger.updateConfig()`, `DiqitLogger.registerConverter<T>()`) act as pure shorthands / forwarders to `DiqitLogger.root`.

### 2. Child / Scoped Loggers Delegate Dynamically to `root`
- Scoped loggers (`DiqitLogger('namespace')`, `DiqitLogger.scoped('namespace')`, or `createChild('sub')`) are lightweight instances carrying a `_path` string (e.g. `'kds/order_grid'`).
- When a scoped logger calls `log()`, it encapsulates the message, tags, and namespace `_path` into a `DLogMessage` and delegates execution to `DiqitLogger.root`.
- Scoped loggers do not duplicate configuration state or output sinks. Any runtime configuration update via static shorthands automatically applies to all scoped loggers.

### 3. Structural `_path` Representation
- `_path` is carried as a dedicated property inside `DLogMessage(path: 'kds/order_grid')`.
- `DPrettyPrinter` renders the path as a clear header label (`[kds/order_grid] -> Message`) for visual inspection and enables exact path-based filtering (`getLogsByPath`).

### 4. DX API Surface
Developers can instantiate scoped loggers using flexible syntax:
```dart
// Short constructor syntax
final logger = DiqitLogger('kds');

// Explicit static factory
final logger = DiqitLogger.scoped('kds');

// Chained namespace creation
final orderGridLogger = logger.createChild('order_grid'); // path: 'kds/order_grid'
```

## Consequences

- **Pros**:
  - Eliminates configuration drift across submodules.
  - Resource efficient: no duplicated file descriptors or WebSocket output servers.
  - Aligns with standard logging ecosystems (`team_logger`, Dart `package:logging`, `slf4j`, `pino`).
- **Cons**:
  - Submodules cannot have independent `LogPrinter` instances separate from root unless explicitly overridden per call.
