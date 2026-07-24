# PRD: Zone-Based Trace Propagation for DiqitLogger

**Date:** 2026-07-24  
**Status:** Ready for Implementation  
**Estimated Effort:** 1.5 days (11 hours)

---

## Problem Statement

Developers working on Diqit POS apps (KDS, OT, Dispatch, Customer Display, Price Display) face a **context propagation problem** when logging across architectural layers:

1. **Manual parameter drilling**: To link related logs (e.g., order acceptance → API call → database save → sound effect), developers must manually pass a correlation ID through 5-10 layers of function calls, adding boilerplate and coupling layers unnecessarily.

2. **Disconnected logs**: Without correlation IDs, logs from a single user action (e.g., "bump order") appear as isolated entries. Debugging production issues requires mentally reconstructing which logs belong together by matching timestamps and messages — error-prone and time-consuming.

3. **No retry/fallback tracking**: When operations retry (e.g., network request failures, driver assignment fallbacks), there's no way to visually group the retry attempts under a parent trace, making it hard to distinguish legitimate retries from separate failures.

4. **Async boundary fragmentation**: Dart's async/await breaks traditional call-stack context. A `Future` spawned in the presentation layer loses its parent context by the time it executes in the data layer, so logs deep in async chains have no link to their originating user action.

**Real-world pain point from KDS:**
```dart
// presentation/order_grid_screen.dart
void _handleBump(OrderItem item) {
  DiqitLogger.info('presentation.kds.order_grid.bump_order.started');
  _bumpUseCase.execute(item);  // ← Context lost here
}

// domain/use_cases/bump_use_case.dart
Future<Either<Failure, Unit>> execute(OrderItem item) async {
  DiqitLogger.debug('domain.use_cases.bump');  // ← No link to presentation log
  return _repository.bumpItem(item);
}

// data/repositories/order_repository.dart
Future<void> bumpItem(OrderItem item) async {
  DiqitLogger.debug('data.repositories.order');  // ← No link to either above
  await _apiClient.post('/bump', item.toJson());
}
```

When debugging "why did bump fail?", developers see 3 disconnected log lines and must manually correlate them by timestamp, guessing which `domain.use_cases.bump` call belongs to which `presentation.kds.order_grid.bump_order.started`.

---

## Solution

Add **Zone-based trace propagation** to `diqit-logging`, enabling automatic correlation ID inheritance across async boundaries without manual parameter passing.

### Core mechanism

```dart
// Wrap any async operation in a trace zone
await DiqitLogger.trace(TraceId.auto('bump-${item.id}'), () async {
  DiqitLogger.info('presentation.kds.order_grid', message: 'Bumping item');
  // ↓ Every log inside this zone automatically inherits #bump-123
  await _bumpUseCase.execute(item);
  // ↓ Even logs 10 layers deep get #bump-123
  DiqitLogger.info('presentation.kds.order_grid', message: 'Bump complete');
});

// Output:
// [kds] Bumping item #bump-123
// [domain] Executing bump logic #bump-123
// [data] POST /bump #bump-123
// [kds] Bump complete #bump-123
```

### Key features

1. **Zero-parameter propagation**: No need to pass `traceId` through function signatures — Dart's `Zone` carries it automatically across `await`, `Future.then`, `Stream`, and callback boundaries.

2. **Lazy auto-increment**: `TraceId.auto('group')` generates unique IDs lazily (only when a log is actually written), avoiding wasted sequence numbers for disabled log levels.

3. **Nested traces**: Child zones append to parent trace lists, creating hierarchies like `[#order-456, #payment-1, #stripe-retry-2]`.

4. **Suffix support**: Retry/fallback scenarios use `.withSuffix('retry-2')` to create sub-traces like `#request-1.retry-2`, visually grouping retries under the parent.

5. **Backward compatible**: Existing code works unchanged — `traceId` is optional, and logs without `trace()` wrappers behave identically to today.

---

## User Stories

1. As a KDS developer, I want all logs from a single "bump order" action to share a trace ID, so that I can filter production logs by `#bump-123` and see the entire flow in one view.

2. As an OT developer, I want to wrap data sync operations in a trace zone, so that logs from `fetchDelta()` → `applyDelta()` → `notifyUI()` are linked without passing a `syncId` parameter through 5 functions.

3. As a Dispatch developer, I want driver assignment logs to show `#assign-driver-1`, and fallback attempts to show `#assign-driver-1.fallback-zone2`, so that I can visually distinguish primary attempts from fallbacks in the log stream.

4. As a backend developer debugging a payment flow, I want nested trace IDs like `[#order-456, #payment-1]`, so that I can see which payment sub-operation belongs to which order without manually matching timestamps.

5. As a developer writing a new feature, I want to add trace IDs to my logs without modifying 10 existing function signatures, so that I can ship faster without refactoring unrelated code.

6. As a developer filtering logs during development, I want to set `LOG_TRACE=#payment-1` as an environment variable, so that only logs with that trace ID are printed, reducing noise from unrelated features.

7. As a QA engineer reproducing a bug, I want to copy a trace ID from a production error report (e.g., `#sync-failed-789`) and search the log file for that ID, so that I can see all related logs in chronological order.

8. As a developer debugging a flaky test, I want each test case to run in its own trace zone with a unique ID, so that parallel test logs don't interleave and confuse which log belongs to which test.

9. As a developer reviewing logs from a batch operation, I want the parent trace `#batch-import-1` to appear on all 1000 item logs, with each item showing `#batch-import-1.item-42`, so that I can filter by parent or drill into a specific item.

10. As a library maintainer, I want `TraceId` to be a sealed class with clear factory constructors, so that callers cannot accidentally create invalid trace IDs and the type system guides correct usage.

11. As a developer using `TraceId.auto('request')`, I want the counter to only increment when the log is actually written (not when the logger is disabled), so that sequence numbers stay dense and don't skip gaps for filtered-out logs.

12. As a developer nesting trace zones (e.g., HTTP request inside a background job), I want the inner zone to append its trace to the outer zone's list (not replace it), so that logs show the full ancestry like `[#job-5, #http-request-12]`.

13. As a developer migrating existing code, I want to add `.trace()` wrappers incrementally, so that I can adopt trace IDs feature-by-feature without a big-bang refactor.

14. As a developer writing synchronous code, I want `DiqitLogger.traceSync()` for non-async functions, so that I can use trace zones in pure functions without fake `async` wrappers.

15. As a developer testing trace propagation, I want unit tests that verify zone values propagate across `await` boundaries, so that I have confidence the mechanism works in production async code.

16. As a developer reading trace logs, I want the format `#group-num` (e.g., `#payment-42`) to be human-scannable, so that I can visually grep trace IDs in a terminal without regex.

17. As a developer debugging a trace-related issue, I want `TraceId.toString()` to return the formatted ID (e.g., `#bump-123`), so that I can log the trace object directly without manual formatting.

18. As a platform engineer, I want the TraceId implementation to follow the team_logger pattern (sealed class, lazy resolution, suffix support), so that we can upgrade to their layout system in Phase 2 without breaking changes.

19. As a developer using retries, I want `traceId.withSuffix('retry-2')` to produce `#request-1.retry-2`, so that I can see retry attempts grouped under the parent request in the log stream.

20. As a developer filtering by trace group, I want to match all traces in a group (e.g., `LOG_TRACE=payment` matches `#payment-1`, `#payment-2`, `#payment-3`), so that I can see all payment-related logs without knowing the exact sequence number.

21. As a developer adopting trace IDs, I want existing `DiqitLogger.info()` calls to accept an optional `traceId` parameter, so that I can manually pass a trace when I don't want to use a zone wrapper (e.g., one-off logs).

22. As a developer reading implementation code, I want `TraceId` to be defined in `lib/src/logger/trace_id.dart` and exported from `lib/diqit_logging.dart`, so that I can import it consistently with other DiqitLogger types.

23. As a developer using `TraceId.manual('group', 42)`, I want a const constructor, so that I can create compile-time constant trace IDs for testing.

24. As a developer calling `DiqitLogger.trace()`, I want the method to return the callback's result, so that I can use it in expressions like `final result = await DiqitLogger.trace(id, () => fetchData())`.

25. As a developer testing zone propagation, I want tests that verify explicit `traceId` parameters override zone-inherited values, so that I can bypass zone context when needed (e.g., logging a global event inside a user-scoped zone).

---

## Implementation Decisions

### Module: TraceId sealed class

**Location:** `lib/src/logger/trace_id.dart`  
**Exported from:** `lib/diqit_logging.dart`

**Interface:**
```dart
sealed class TraceId {
  const factory TraceId.manual(String group, int num);
  factory TraceId.auto(String group, {int initial = 1});
  factory TraceId.global({int initial = 1});
  
  String? get group;
  int get num;
  String? get suffix;
  
  TraceId withSuffix(String suffix);
  void resolve();  // Force lazy counter increment
  String toString();  // Returns "#group-num" or "#num" or "#group-num.suffix"
}
```

**Three implementations:**
1. `_ConstTraceId` — immutable, created by `.manual()`
2. `_LazyAutoTraceId` — mutable, lazy counter per group, created by `.auto()` or `.global()`
3. `_TraceIdWithSuffix` — wrapper that appends suffix to base trace

**Lazy resolution strategy:**
- `_LazyAutoTraceId` holds a `int? _num` field, initially `null`
- On first `num` access, increment global `Map<String?, int> _autoNums` counter for that group
- `resolve()` method forces immediate resolution (called by logger before emitting log)
- This avoids wasting sequence numbers when logs are disabled by level/tag filters

**Suffix mechanism:**
- `withSuffix('retry')` wraps existing trace in `_TraceIdWithSuffix`
- Multiple suffixes chain: `id.withSuffix('a').withSuffix('b')` produces `#group-1.a.b`
- Base trace's counter is only incremented once, even with multiple suffix wrappers

**toString format:**
- `TraceId.manual('payment', 42)` → `"#payment-42"`
- `TraceId.auto('request')` → `"#request-1"` (first call), `"#request-2"` (second call)
- `TraceId.global()` → `"#1"`, `"#2"`, etc.
- `TraceId.auto('req').withSuffix('retry-2')` → `"#req-1.retry-2"`

---

### Module: Zone propagation utilities

**Location:** `lib/src/logger/zone_trace.dart` (internal, not exported)

**Purpose:** Encapsulate Zone manipulation logic, keep `DiqitLogger` class clean.

**Interface:**
```dart
class ZoneTrace {
  static const _traceIdKey = #diqit_logger_trace_ids;
  
  static List<TraceId> getTraceIds([Zone? zone]);
  static T runWithTrace<T>(TraceId traceId, T Function() fn);
  static Future<T> runWithTraceAsync<T>(TraceId traceId, Future<T> Function() fn);
}
```

**Zone storage:**
- Store `List<TraceId>` in zone values under key `#diqit_logger_trace_ids`
- When entering a nested trace zone, append new trace to parent's list (don't replace)
- Example: outer zone has `[#order-123]`, inner zone has `[#order-123, #payment-1]`

**Retrieval:**
- `getTraceIds()` checks `Zone.current[_traceIdKey]`, returns empty list if not found
- Called by logger before emitting each log line
- All traces in the list are rendered in log output (e.g., `"Message #order-123 #payment-1"`)

---

### Module: DiqitLogger API additions

**Changes to:** `lib/src/diqit_logging.dart`

**New static methods:**
```dart
class DiqitLogger {
  /// Runs [fn] in a trace zone. All logs emitted inside [fn] inherit [traceId].
  /// Returns the result of [fn].
  static Future<T> trace<T>(TraceId traceId, Future<T> Function() fn);
  
  /// Synchronous version for non-async code.
  static T traceSync<T>(TraceId traceId, T Function() fn);
}
```

**Implementation:**
- Delegate to `ZoneTrace.runWithTraceAsync()` / `ZoneTrace.runWithTrace()`
- Call `traceId.resolve()` before entering zone (force lazy counter increment)
- Use `runZoned()` to create new zone with trace list in zone values

**New optional parameter on all log methods:**
```dart
static void info(
  String tag, {
  String? message,
  Object? error,
  StackTrace? stackTrace,
  LogPrinter? printer,
  bool countMethod = false,
  TraceId? traceId,  // ← NEW
});
```

**Trace resolution precedence:**
1. If `traceId` parameter is provided, use it (override zone)
2. Else, retrieve from `Zone.current` via `ZoneTrace.getTraceIds()`
3. If no zone trace, render log without trace ID (backward compatible)

**Log output format:**
- Append trace IDs to message: `"[tag] message #trace1 #trace2"`
- If multiple traces from nested zones, space-separate them
- Ensure `DiqitPrettyPrinter` renders trace IDs in a distinct color (dim gray or blue)

---

### Module: LoggerConfig environment variable filter

**Changes to:** `lib/src/logger/logger_config.dart`

**New optional parameter:**
```dart
class LoggerConfig {
  final List<String>? traceIdPatterns;  // ← NEW
  
  LoggerConfig({
    // ... existing params
    this.traceIdPatterns,
  });
}
```

**Initialization from environment:**
```dart
factory LoggerConfig.development({...}) {
  final traceEnv = const String.fromEnvironment('LOG_TRACE', defaultValue: '');
  final resolvedTracePatterns = traceEnv.isNotEmpty
      ? traceEnv.split(',').map((e) => e.trim()).toList()
      : null;
  
  return LoggerConfig(
    // ... existing config
    traceIdPatterns: resolvedTracePatterns,
  );
}
```

**Filter logic:**
- If `traceIdPatterns` is `null`, log everything (no filter)
- If `traceIdPatterns` is `['payment']`, only log lines with a trace matching group `'payment'`
- If `traceIdPatterns` is `['payment-42']`, only log lines with exact trace `#payment-42`
- Matching is substring-based: pattern `'pay'` matches `#payment-1`, `#pay-abc`, etc.

**Integration point:**
- In `_InlineFilter.shouldLog()` (from refactor #1), check trace IDs after tag/level filtering
- If log line has traces, check if any trace's `toString()` contains any pattern
- If no match, return `false` (suppress log)

---

### Architectural decision: Why Zone over Context objects?

**Alternatives considered:**
1. **Manual context parameter** — `execute(OrderItem item, LogContext ctx)`
   - ❌ Requires changing every function signature in the call chain
   - ❌ Couples business logic to logging infrastructure
   - ❌ Breaks when refactoring function signatures

2. **ThreadLocal-style global** — `DiqitLogger.setCurrentTrace(id)`
   - ❌ Not safe in async Dart (multiple futures share same isolate)
   - ❌ Requires manual cleanup (`try/finally`) to avoid leaking trace across operations

3. **Middleware/Interceptor pattern** — BLoC events carry trace IDs
   - ❌ Only works within BLoC layer, doesn't cover repository/API calls
   - ❌ Requires wrapping every event type with trace metadata

**Why Zone wins:**
- ✅ Native Dart mechanism designed for async context propagation
- ✅ Automatic cleanup when zone exits (no manual try/finally)
- ✅ Works across `await`, `Future.then`, `Stream`, timers, and callbacks
- ✅ Zero changes to existing function signatures
- ✅ Dart SDK itself uses Zone for error handling and logging (e.g., `runZonedGuarded`)

**Trade-off:**
- ⚠️ Zone values are dynamic (`Object?`), requiring runtime cast
- ⚠️ Slightly harder to test than explicit parameters (must use `runZoned` in tests)
- Mitigated by: wrapping in `ZoneTrace` utility with typed API, extensive integration tests

---

### Schema changes

None — this is a pure addition. No database, no breaking API changes.

---

### API contracts

**Public API additions:**
```dart
// New types
sealed class TraceId { ... }

// New methods
DiqitLogger.trace<T>(TraceId, Future<T> Function()) -> Future<T>
DiqitLogger.traceSync<T>(TraceId, T Function()) -> T

// Modified methods (backward compatible)
DiqitLogger.info(String, {TraceId? traceId, ...}) -> void
// Same for: trace, debug, info, warning, error, fatal, t, d, i, w, e, ft
```

**No breaking changes:**
- All new parameters are optional
- Existing calls work identically
- Trace IDs only appear in output if explicitly used

---

### Specific interactions

**Interaction 1: Nested trace zones**
```dart
await DiqitLogger.trace(TraceId.auto('order'), () async {
  DiqitLogger.info('...');  // Output: "... #order-1"
  
  await DiqitLogger.trace(TraceId.auto('payment'), () async {
    DiqitLogger.info('...');  // Output: "... #order-1 #payment-1"
  });
  
  DiqitLogger.info('...');  // Output: "... #order-1" (payment zone exited)
});
```

**Interaction 2: Manual override**
```dart
await DiqitLogger.trace(TraceId.auto('order'), () async {
  DiqitLogger.info('...', traceId: TraceId.manual('override', 99));
  // Output: "... #override-99" (zone trace ignored)
});
```

**Interaction 3: Retry with suffix**
```dart
final traceId = TraceId.auto('request');
DiqitLogger.info('Initial attempt', traceId: traceId);  // #request-1

for (var i = 0; i < 3; i++) {
  DiqitLogger.warning(
    'Retry attempt ${i+1}',
    traceId: traceId.withSuffix('retry-${i+1}'),
  );  // #request-1.retry-1, #request-1.retry-2, #request-1.retry-3
}
```

**Interaction 4: Filter by trace group**
```bash
# Run app with trace filter
LOG_TRACE=payment dart run main.dart

# Only logs with #payment-1, #payment-2, etc. are printed
# Logs with #order-123, #sync-5, or no trace are suppressed
```

---

## Testing Decisions

### What makes a good test

**Test external behavior, not implementation:**
- ✅ Verify that logs emitted inside `trace()` contain the trace ID in output
- ✅ Verify that nested zones append traces to the list
- ✅ Verify that trace filtering suppresses logs without matching traces
- ❌ Don't test internal Zone.current manipulation — that's implementation detail
- ❌ Don't test `_LazyAutoTraceId._num` field directly — test through public `num` getter

**Test through public API:**
- All tests call `DiqitLogger.trace()`, `DiqitLogger.info()`, etc. — never instantiate internal classes like `ZoneTrace` directly
- Tests capture log output via `LogHistoryManager` or mock `LogOutput`, not by inspecting private fields

---

### Module 1: TraceId sealed class

**Test file:** `test/src/logger/trace_id_test.dart`

**Coverage:**
1. `TraceId.manual('group', 42).toString()` returns `"#group-42"`
2. `TraceId.auto('group')` returns `#group-1`, `#group-2` on successive calls (lazy increment)
3. `TraceId.global()` returns `#1`, `#2` (no group prefix)
4. `TraceId.auto('group')` doesn't increment until `.num` is accessed (lazy)
5. `traceId.withSuffix('retry')` returns `#group-1.retry`
6. Chained suffixes: `id.withSuffix('a').withSuffix('b')` returns `#group-1.a.b`
7. `.resolve()` forces lazy counter increment before `.num` is accessed
8. Different groups have independent counters: `TraceId.auto('a')` and `TraceId.auto('b')` both start at 1

**Prior art:** `test/src/logger/printer_selector_test.dart` — unit tests for isolated logic modules

---

### Module 2: Zone propagation

**Test file:** `test/src/logger/zone_trace_test.dart`

**Coverage:**
1. `DiqitLogger.trace()` — logs inside callback contain trace ID
2. Nested `trace()` — inner zone appends to outer zone's trace list
3. Trace survives `await` — async function called inside `trace()` inherits trace
4. Trace survives `Future.delayed` — callback scheduled for later inherits trace
5. Manual `traceId` parameter overrides zone trace
6. No `trace()` wrapper — logs without zone still work (no trace ID in output)
7. `traceSync()` — synchronous version works without `async`
8. Multiple traces in nested zones render space-separated: `#order-1 #payment-2`

**Prior art:** 
- `test/src/flow_tracing_test.dart` — existing tests for flow tracing (if any)
- `test/src/update_config_test.dart` — integration tests that initialize logger and verify behavior

---

### Module 3: Trace filtering

**Test file:** `test/src/logger/trace_filter_test.dart`

**Coverage:**
1. `LOG_TRACE=payment` — only logs with `#payment-X` appear
2. `LOG_TRACE=payment-42` — only logs with exact `#payment-42` appear
3. `LOG_TRACE=payment,order` — logs with either `#payment-X` or `#order-X` appear
4. No `LOG_TRACE` set — all logs appear (no filtering)
5. Log without trace ID — suppressed when filter is active
6. Log with non-matching trace — suppressed
7. Nested traces — log appears if ANY trace matches filter

**Prior art:** `test/src/update_config_test.dart` — tests for `LoggerConfig` updates (tag filtering already exists, this mirrors that pattern)

---

### Integration test: Real-world scenario

**Test file:** `test/src/integration/trace_propagation_integration_test.dart`

**Scenario:** Simulate KDS bump flow
```dart
test('Bump order flow links presentation → domain → data logs', () async {
  await DiqitLogger.initialize(LoggerConfig.development());
  
  await DiqitLogger.trace(TraceId.auto('bump'), () async {
    DiqitLogger.info('presentation.kds', message: 'Bump started');
    await _simulateDomainLayer();
    DiqitLogger.info('presentation.kds', message: 'Bump completed');
  });
  
  final logs = DiqitLogger.exportLogs();
  
  expect(logs, contains('#bump-1'));  // All logs have same trace
  expect(logs, contains('presentation.kds'));
  expect(logs, contains('domain.use_cases'));
  expect(logs, contains('data.repositories'));
});

Future<void> _simulateDomainLayer() async {
  DiqitLogger.debug('domain.use_cases', message: 'Executing bump');
  await _simulateDataLayer();
}

Future<void> _simulateDataLayer() async {
  await Future.delayed(Duration(milliseconds: 10));
  DiqitLogger.debug('data.repositories', message: 'API call complete');
}
```

**Verifies:** Trace propagates through 3 layers without explicit parameters, survives `await`, and appears in exported log output.

---

## Out of Scope

**Hierarchical loggers (Phase 2):**
- `DiqitLogger.createChild('kds')` — deferred to separate PRD
- Namespace paths like `app/payment/network` — not in this phase
- Tag inheritance from parent loggers — not in this phase

**Modular layout system (Phase 3):**
- Row-based log formatting (`LogRow`, `LogSequenceNum`, `LogTime`) — deferred
- Per-app printer customization — deferred
- BBCode formatting in log messages — deferred

**Distributed tracing:**
- Propagating trace IDs across HTTP boundaries (e.g., KDS → OT Master) — requires backend coordination, not in scope
- OpenTelemetry integration — not in scope
- Trace visualization UI — not in scope

**Advanced filtering:**
- Filtering by trace ID suffix (e.g., `LOG_TRACE=*.retry-*`) — not in scope, only group/exact match supported
- Filtering by multiple conditions (e.g., `LOG_TRACE=payment AND LOG_TAG=network`) — not in scope

**Trace sampling:**
- Probabilistic logging (e.g., "log 10% of requests") — not in scope
- Rate limiting trace ID generation — not in scope

---

## Further Notes

**Migration path for existing apps:**
- ✅ **Day 1:** Merge this feature, no app changes required (backward compatible)
- ✅ **Week 1-2:** KDS team wraps order bump flow in `trace()`, validates trace IDs appear in logs
- ✅ **Week 3-4:** OT team wraps sync operations, Dispatch team wraps driver assignment
- ✅ **Month 2:** Add trace filtering to production log viewers (grep for `#trace-id`)

**Performance impact:**
- Zone creation overhead: ~10μs per `runZoned()` call (negligible for user-facing actions)
- Lazy counter increment: ~1μs per trace (HashMap lookup + increment)
- No impact on logs that don't use traces (zone check returns empty list immediately)

**Documentation updates required:**
1. Update `AGENTS.md` — add section on `DiqitLogger.trace()` usage
2. Update `README.md` — add "Trace Propagation" section with examples
3. Add `docs/guides/trace-propagation.md` — comprehensive guide with KDS/OT/Dispatch examples
4. Update per-app rules (`.claude/rules/kds-context.md`, etc.) — mention trace pattern for each app

**Inspiration credit:**
- TraceId design based on [team_logger](https://github.com/vi-k/team_logger) by vi-k
- Analysis document: `docs/agents/team_logger_analysis.md`

**Estimated delivery:**
- Implementation: 7 hours
- Tests: 2 hours
- Documentation: 2 hours
- **Total: 11 hours (1.5 days)**

**Success metrics:**
- Zero breaking changes — all existing tests pass
- 18+ new tests covering TraceId + Zone propagation
- At least 1 real-world integration in KDS or OT within 2 weeks of merge
