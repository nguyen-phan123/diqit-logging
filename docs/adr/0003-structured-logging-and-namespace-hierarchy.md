# 0003: Structured Object Logging

- **Status**: Proposed
- **Date**: 2026-07-26
- **Authors**: Platform Team
- **Inspired by**: [team_logger](https://github.com/vi-k/team_logger) Loggable pattern

## Context

DiqitLogger currently provides a **singleton-based logging API** with good primitives (trace zones, tag filtering, dual printers). However, one critical gap emerges when logging domain entities:

### Complex objects log poorly

```dart
// Current: objects dump as toString() or require manual formatting
final order = OrderEntity(uuid: 'abc-123', total: 45.50, items: [...]);
DiqitLogger.i('Order created: $order');
// Output: Order created: Instance of 'OrderEntity'

// Workaround: manual serialization in every call site
DiqitLogger.i('Order created: uuid=${order.uuid}, total=${order.total}, items=${order.orderDetails.length}');
// Verbose, inconsistent across codebase, error-prone
```

**Problem:** No standard protocol for logging domain entities (OrderEntity, KdsBatchesEntity, SocketEnvelope, CartModel) with readable structure. Teams resort to:
1. Opaque `toString()` output (useless)
2. Manual string interpolation (verbose, inconsistent)
3. Custom `toDebugString()` methods (scattered, no convention)

This compounds in a **monorepo with 5 Flutter apps** where entities are logged hundreds of times across features.

## Decision

We adopt **2 features** from `team_logger` to solve structured object logging:

### 1. Loggable Mixin
A protocol for domain entities to define their structured log representation.

### 2. Type Converter Registry
A fallback mechanism for formatting third-party types that cannot implement `Loggable`.

**Not adopting** (evaluated but deemed over-engineered for current needs):
- ❌ **Namespace loggers** — LogTag already provides domain filtering; hierarchical paths add complexity without clear benefit
- ❌ **Custom themes** — DShorthandPrinter/DPrettyPrinter work fine; theme abstraction premature until production format breaks
- ❌ **BBCode formatting** — ANSI codes exist; inline markup is visual sugar, not functional requirement
- ❌ **Active/Inactive modes** — Visual polish without measurable value

---

## Architecture Design

### 1. Loggable Mixin

**Goal:** Standard protocol for structured object logging.

```dart
// lib/src/logger/loggable.dart
/// {@template loggable}
/// Protocol for objects that can format themselves for logging.
/// 
/// Implement this mixin on domain entities to provide structured
/// key-value representation instead of opaque toString() output.
/// {@endtemplate}
mixin Loggable {
  /// Returns a map of loggable key-value pairs.
  /// Keys should be human-readable field names.
  /// Values can be primitives, strings, or nested Loggable objects.
  Map<String, dynamic> toLoggableMap();
}
```

**Usage in domain layer:**
```dart
// lib/domain/entities/order_entity.dart
class OrderEntity with Loggable {
  final String uuid;
  final double total;
  final List<OrderDetailEntity> orderDetails;
  final OrderStatus status;

  @override
  Map<String, dynamic> toLoggableMap() => {
    'uuid': uuid,
    'total': '\$${total.toStringAsFixed(2)}',
    'items_count': orderDetails.length,
    'status': status.name,
  };
}

// Usage
DiqitLogger.i('Order created', data: orderEntity);
// Output: [10:30:45] ℹ [OTM] [ORDER] Order created
//         Data: {uuid: abc-123, total: $45.50, items_count: 3, status: pending}
```

**Implementation details:**
- Add optional `Object? data` parameter to all log methods (`i`, `d`, `w`, `e`, `ft`, etc.)
- Printer detects `Loggable` via `data is Loggable` check
- Format as indented key-value pairs (console-friendly)
- Recursively format nested Loggable objects
- Falls back to TypeConverter if not Loggable (see below)
- Last resort: `data.toString()`

---

### 2. Type Converter Registry

**Goal:** Format third-party classes that cannot implement `Loggable`.

```dart
// lib/src/logger/type_converter.dart
typedef TypeConverter<T> = String Function(T value);

class TypeConverterRegistry {
  final Map<Type, TypeConverter> _converters = {};
  
  /// Register a converter for type [T].
  void register<T>(TypeConverter<T> converter) {
    _converters[T] = converter;
  }
  
  /// Try to convert [value] using registered converter.
  /// Returns null if no converter found for value's type.
  String? convert(Object value) {
    final converter = _converters[value.runtimeType];
    if (converter != null) {
      return converter(value);
    }
    return null;
  }
}
```

**Usage:**
```dart
// During logger initialization
await DiqitLogger.initialize(config);

// Register common types
DiqitLogger.registerConverter<DateTime>((dt) => dt.toIso8601String());
DiqitLogger.registerConverter<Duration>((d) => '${d.inSeconds}s');
DiqitLogger.registerConverter<Uri>((uri) => uri.toString());

// Later in code
DiqitLogger.i('Event scheduled at', data: DateTime.now());
// Output: Event scheduled at
//         Data: 2026-07-26T10:30:45.123Z

DiqitLogger.d('Request timeout', data: Duration(seconds: 30));
// Output: Request timeout
//         Data: 30s
```

**Lookup order for `data` parameter:**
1. **Loggable check** → `data.toLoggableMap()` if implements mixin
2. **TypeConverter check** → registered converter if exists
3. **Fallback** → `data.toString()`

---

## Implementation Plan

### Single Phase (2 days)

**Ticket 1.1: Loggable Mixin Protocol** (4 hours)
- Create `lib/src/logger/loggable.dart` with mixin definition
- Update exports in `lib/diqit_logging.dart`
- Add dartdoc with usage examples

**Ticket 1.2: Type Converter Registry** (4 hours)
- Create `lib/src/logger/type_converter.dart`
- Add `TypeConverterRegistry` class to `DiqitLogger` singleton
- Expose `DiqitLogger.registerConverter<T>()` static method
- Register DateTime/Duration/Uri by default in `initialize()`

**Ticket 1.3: Data Parameter & Printer Integration** (1 day)
- Add `Object? data` parameter to all log methods
- Update `DiqitLogPrinter._formatMessage()` to detect and format data:
  ```dart
  String _formatDataIfPresent(Object? data) {
    if (data == null) return '';
    
    // 1. Try Loggable
    if (data is Loggable) {
      final map = data.toLoggableMap();
      return _formatMap(map, indent: 2);
    }
    
    // 2. Try TypeConverter
    final converted = _converterRegistry.convert(data);
    if (converted != null) return '\n  Data: $converted';
    
    // 3. Fallback
    return '\n  Data: ${data.toString()}';
  }
  ```
- Handle nested Loggable objects recursively
- Add tests for all 3 lookup paths

**Ticket 1.4: Documentation** (2 hours)
- Update README.md with Loggable usage examples
- Add migration guide for existing manual formatting patterns
- Document best practices (when to use Loggable vs TypeConverter)

**Total effort:** 2 days

---

## Consequences

### Positive
- **Immediate value** — log complex objects readably without manual formatting at every call site
- **Consistent convention** — one way to format entities across monorepo
- **Low risk** — additive API (`data` parameter optional), zero breaking changes
- **Pragmatic scope** — solves real problem (unreadable objects), doesn't add speculative features
- **Extensible** — TypeConverter registry allows formatting any type without modifying its source

### Negative
- **Adoption effort** — requires adding `Loggable` mixin to ~20-30 domain entities across apps
- **Boilerplate** — every entity needs `toLoggableMap()` implementation (mitigated: one-time, localized in entity files)

### Neutral
- **Deferred features** — namespace hierarchy, custom themes, BBCode remain unimplemented. Re-evaluate if:
  - LogTag filtering proves insufficient (namespace hierarchy)
  - Production needs JSON format for log aggregator (custom themes)
  - Visual emphasis becomes a repeated pain point (BBCode)

---

## Alternatives Considered

### Alternative 1: Adopt team_logger directly
**Pros:** Battle-tested, full feature set (namespace, themes, BBCode)  
**Cons:** 
- Requires replacing DiqitLogger singleton (breaking change)
- Loses existing TraceEnvelope/Socket.IO integration
- External dependency vs in-house control
- Over-engineered for current need

**Verdict:** Rejected. Too disruptive for incremental value.

---

### Alternative 2: JSON serialization (toJson)
**Pros:** Standard Dart pattern, code gen via json_serializable  
**Cons:** 
- toJson is for **wire format**, not **human-readable logs**
- Would produce JSON strings in console (hard to read)
- Couples logging to serialization concerns

**Verdict:** Rejected. Loggable is logging-specific protocol.

---

### Alternative 3: Keep manual formatting
**Pros:** Zero new code  
**Cons:** 
- Inconsistent across codebase
- Verbose, error-prone
- No enforcement of structured format

**Verdict:** Rejected. Problem is real, solution is low-cost.

---

## Related ADRs
- [0001: Zone-based Tracing](./0001-zone-based-tracing.md) — TraceZone foundation
- [0002: Typed TraceId and Stack-based Nesting](./0002-typed-trace-id-and-stack-nesting.md) — TraceId value object

---

## References
- [team_logger GitHub](https://github.com/vi-k/team_logger) — Inspiration for Loggable pattern
- [Dart Mixins](https://dart.dev/language/mixins) — Underlying protocol mechanism
