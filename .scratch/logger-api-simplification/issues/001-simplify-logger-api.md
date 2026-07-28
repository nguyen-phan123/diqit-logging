---
status: ready-for-agent
created: 2026-07-28
labels: [ready-for-agent, refactor]
---

# Simplify DiqitLogger API Surface

## Problem Statement

Developers face API inconsistency when using DiqitLogger. The static API offers both shortcut methods (`i()`, `d()`, `w()`) and full methods (`info()`, `debug()`, `warning()`), but instance loggers created via `createChild()` only expose the verbose `log(Level.xxx, message)` method. This forces different usage patterns depending on whether you're logging statically or through a child logger, creating cognitive overhead and reducing code readability.

Additionally, the full methods were originally designed to support `countMethod` parameter for stack trace depth control, but the logging system no longer uses stack traces as the primary diagnostic mechanism — TraceId and ZoneTrace now handle flow correlation. This leaves the full methods without a compelling use case, yet they represent 25% of current usage (60 out of 242 total calls across the monorepo).

## Solution

Standardize the API around shortcut methods only, available uniformly on both static and instance loggers. Deprecate the full methods (`trace()`, `debug()`, `info()`, `warning()`, `error()`, `fatal()`) with clear migration guidance since their differentiating feature (`countMethod`) is obsolete in the current architecture. This produces a single, consistent logging pattern across the codebase while maintaining backward compatibility during the transition period.

## User Stories

1. As a developer creating a child logger, I want to use `logger.i('message')` instead of `logger.log(Level.info, 'message')`, so that my instance logging code reads as concisely as my static logging code.

2. As a developer maintaining KDS order grid code, I want `kdsLogger.d('bump started')` to work the same way `DiqitLogger.d()` does, so that I don't need to remember two different APIs.

3. As a developer reviewing code, I want all log calls to use the same shortcut methods, so that I can quickly scan for logging patterns without parsing different syntaxes.

4. As a developer migrating from full methods to shortcuts, I want clear deprecation messages, so that I know exactly which shortcut replaces each full method.

5. As a developer using static logging, I want the `@Deprecated` warning removed from shortcut methods, so that my IDE stops flagging the recommended API as outdated.

6. As a developer writing tests, I want instance logger shortcuts to integrate with `getLogHistory()`, so that I can verify child logger output using the same testing pattern as static logs.

7. As a developer working in the OT app, I want `otLogger.w('connection lost')` to automatically include the `[ot]` namespace path, so that I get subsystem attribution without manual tagging.

8. As a developer creating nested child loggers, I want `gridLogger.e('bump failed', error: err)` to produce the correct `[kds/order_grid]` path, so that hierarchical namespaces work naturally with shortcuts.

9. As a platform team member, I want full methods removed from the API surface after a deprecation period, so that we reduce the cognitive load of maintaining two parallel logging APIs.

10. As a developer reading the DiqitLogger documentation, I want to see only shortcut methods in examples, so that I learn the canonical API pattern from the start.

11. As a developer debugging with TraceId, I want `logger.i('event', traceId: tid)` to work on instance loggers, so that I can explicitly override zone-propagated traces when needed.

12. As a developer using LogTag filters, I want `logger.w('timeout', tag: LogTag.network)` on child loggers, so that I can layer-tag logs from namespaced subsystems.

13. As a developer working with Loggable entities, I want `logger.d('order', data: order)` to format structured data the same way static calls do, so that data logging is consistent across static and instance usage.

14. As a developer using zone-based tracing, I want child logger shortcuts to inherit `currentTraceId` automatically, so that nested trace propagation works transparently.

15. As a developer passing custom context, I want `logger.i('event', context: {'order_id': '123'})` to work on instance loggers, so that entity-based filtering works uniformly.

## Implementation Decisions

### API Surface Changes

**Update full method deprecation messages**:
- Keep `trace()`, `debug()`, `info()`, `warning()`, `error()`, `fatal()` in the codebase with updated deprecation warnings
- Change deprecation message to reference shortcut equivalents and v2.0.0 removal timeline
- The `countMethod` parameter had no remaining use case — TraceId and ZoneTrace replaced stack-trace-based flow correlation
- Full methods represented only 25% of usage (60/242 calls), indicating low adoption

**Undeprecate static shortcuts**:
- Remove `@Deprecated` annotations from `t()`, `d()`, `i()`, `w()`, `e()`, `ft()`
- These become the canonical, recommended API for static logging
- Update inline documentation to reflect this as the primary API

**Add instance shortcuts**:
- Implement `t()`, `d()`, `i()`, `w()`, `e()`, `ft()` as instance methods on DiqitLogger
- Signature matches static shortcuts minus the `printer` parameter (which was rarely used and complicates the instance API)
- Each delegates to the existing `log()` method with `shorthand: true`

### Method Signatures

Instance shortcuts follow this pattern:

```dart
void i(String message, {
  dynamic data,
  LogTag tag = LogTag.none,
  TraceId? traceId,
  Map<String, dynamic>? context,
});

void e(String message, {
  dynamic data,
  LogTag tag = LogTag.none,
  dynamic error,
  StackTrace? stackTrace,
  TraceId? traceId,
  Map<String, dynamic>? context,
});
```

Static shortcuts retain their current signature (including the rarely-used `printer` parameter for backward compatibility).

### Delegation Path

Instance shortcuts delegate to the existing `log()` method:

```dart
void i(String message, {
  dynamic data,
  LogTag tag = LogTag.none,
  TraceId? traceId,
  Map<String, dynamic>? context,
}) => log(Level.info, message,
      data: data, tag: tag,
      traceId: traceId, context: context);
```

This ensures:
- Namespace path (`_path`) propagates correctly
- TypeConverter registry is respected
- ZoneTrace inheritance works automatically
- All LogOutput targets receive events (console, file, network, memory buffer)

### Namespace Path Behavior

Instance shortcuts automatically inject the logger's `_path`:
- `DiqitLogger.root.createChild('kds')` → logs include `[kds]`
- `kdsLogger.createChild('order_grid')` → logs include `[kds/order_grid]`
- This happens transparently via the `log()` method's existing path resolution

### Deprecation Strategy

Full methods remain in the codebase with updated deprecation messages:

```dart
@Deprecated('Use DiqitLogger.i() instead. Full methods will be removed in v2.0.0')
static void info(...) => ...
```

This gives the team time to migrate 60 call sites across the monorepo without breaking existing code immediately.

### Module Changes

**DiqitLogger class**:
- Add 6 instance methods: `t()`, `d()`, `i()`, `w()`, `e()`, `ft()`
- Remove `@Deprecated` from 6 static shortcuts
- Update deprecation messages on 6 full methods to reference shortcuts
- No changes to `log()` method — it remains the implementation primitive

**No changes required**:
- LoggerConfig — configuration is orthogonal to API surface
- LogTag, TraceId, ZoneTrace — these work with any log method
- NetworkOutput, file output, memory buffer — output targets are agnostic to which method was called
- TypeConverter registry — data formatting is handled by `log()`

## Testing Decisions

### What Makes a Good Test

Tests verify **external behavior** observed through the `getLogHistory()` seam:
- Log messages appear in the buffer
- Namespace paths appear correctly in formatted output
- TraceId, LogTag, and context propagate through to formatted lines
- All parameters (data, error, stackTrace) reach the output as expected

Tests do NOT verify:
- Which internal method was called (`log()` vs direct Logger call)
- Printer selection logic (implementation detail)
- Internal delegation paths

### Modules to Test

**DiqitLogger instance shortcuts**:
- All 6 methods produce output
- Namespace path appears in logs
- Parameters (data, tag, traceId, context) propagate correctly
- Nested child loggers produce compound paths (`parent/child`)

**Static shortcut undeprecation**:
- No behavioral change — deprecation removal is a metadata change
- Existing tests already cover static shortcuts (`diqit_logging_test.dart` line 15-27)

**Full method deprecation**:
- No new tests needed — deprecation is a compiler warning, not runtime behavior
- Existing test at line 22-26 demonstrates full methods still work

### Prior Art

**Existing test patterns**:
- `test/src/diqit_logging_test.dart` (line 15-27) — uses `getLogHistory()` to verify static shortcuts
- `test/src/trace_propagation_integration_test.dart` (line 22-37) — verifies child logger output via buffer inspection
- `test/src/diqit_log_message_format_test.dart` — validates structured data formatting

**Reuse this pattern**:

```dart
test('instance shortcut produces output with namespace path', () async {
  await DiqitLogger.initialize(LoggerConfig.development());
  
  final kdsLogger = DiqitLogger.root.createChild('kds');
  kdsLogger.i('order_bumped');
  
  final logs = DiqitLogger.getLogHistory();
  final logLines = logs.last.lines;
  
  expect(logLines.any((l) => l.contains('order_bumped')), true);
  expect(logLines.any((l) => l.contains('[kds]')), true);
});
```

### Test Coverage

New tests required:
- Instance `i()` with message only
- Instance `d()` with data parameter
- Instance `w()` with LogTag
- Instance `e()` with error and stackTrace
- Nested child logger produces compound path
- Instance shortcut with explicit TraceId
- Instance shortcut inherits zone TraceId

No tests required:
- Static shortcuts (already covered)
- Full methods (already covered, will be removed later)
- Deprecation annotations (compile-time, not runtime)

## Out of Scope

### Not Included in This Change

**Migration of existing full method call sites**:
- 60 calls to `info()`, `debug()`, `warning()`, etc. across the monorepo remain untouched
- Deprecation warnings guide developers to migrate over time
- A separate cleanup PR will address these after the API change lands

**Removal of full methods**:
- Methods remain in the codebase with deprecation warnings
- Actual removal is a breaking change for v2.0.0
- This PR only establishes the canonical API and deprecation path

**Changes to `log()` method**:
- The verbose `log(Level.xxx, message)` API remains available
- Useful for dynamic level selection or programmatic logging
- Shortcuts are convenience wrappers, not replacements for `log()`

**Changes to LoggerConfig or filtering**:
- Tag filtering, log levels, and output configuration are orthogonal
- No changes to how logs are processed, only how they're authored

**Documentation updates beyond inline docs**:
- README, migration guides, or tutorial updates are separate tasks
- This PR focuses on code and inline dartdoc comments

**Performance optimization**:
- Delegation through `log()` adds one method call
- Negligible overhead compared to I/O (console, file, network)
- No profiling or optimization work included

### Intentionally Excluded

**`printer` parameter on instance shortcuts**:
- Static shortcuts retain this for backward compatibility
- Instance shortcuts omit it to keep the API simple
- Rarely used in practice — only 2 occurrences found in tests
- Advanced users can still call `log()` directly with a custom printer

**Sync between static and instance full methods**:
- Since full methods are deprecated and will be removed, adding instance equivalents (`logger.info()`, `logger.debug()`) would expand a dead-end API
- The goal is consolidation, not parity with deprecated methods

## Further Notes

### Migration Path for Teams

Once this PR lands:
1. New code uses shortcuts exclusively (`DiqitLogger.i()`, `logger.d()`)
2. Existing full method calls show deprecation warnings in IDE
3. Developers migrate opportunistically when touching related code
4. A future PR removes full methods and updates all remaining call sites in one pass

### Consistency with Dart Ecosystem

Shortcut logging methods are common in Dart logging libraries:
- `logger` package: `logger.i()`, `logger.d()`, `logger.w()`
- `fimber`: `Fimber.i()`, `Fimber.d()`
- `f_logs`: `FLog.info()`, `FLog.debug()`

DiqitLogger's shortcuts now align with ecosystem conventions, reducing onboarding friction for developers familiar with other Dart loggers.

### Why Not Keep Both APIs?

Maintaining parallel APIs (shortcuts + full methods) creates:
- **Cognitive overhead** — developers must choose between two equivalent options
- **Inconsistent codebases** — some files use shortcuts, others use full methods
- **Larger API surface** — 12 methods instead of 6, with no functional benefit
- **Documentation burden** — every example must choose one style, implicitly deprecating the other

Since `countMethod` is obsolete, full methods have no differentiating value. Removing them simplifies the mental model: one logger, one canonical way to log.

### Impact on Existing Code

**Before**:
```dart
// Static logging
DiqitLogger.i('Started');  // Deprecated warning
DiqitLogger.info('Started', countMethod: 2);  // No warning

// Instance logging
final logger = DiqitLogger.root.createChild('kds');
logger.log(Level.info, 'Bump started');  // Verbose
```

**After**:
```dart
// Static logging
DiqitLogger.i('Started');  // ✅ Canonical API, no warning

// Instance logging
final logger = DiqitLogger.root.createChild('kds');
logger.i('Bump started');  // ✅ Concise, consistent
```

### Estimated Effort

- **Implementation**: 1-2 hours (6 methods, straightforward delegation)
- **Testing**: 1-2 hours (7 test cases, reusing existing patterns)
- **Code review**: 30 minutes (small, focused change)
- **Migration planning**: Out of scope for this PR

**Total**: ~3-4 hours for the API change itself. Monorepo-wide migration is a separate effort.
