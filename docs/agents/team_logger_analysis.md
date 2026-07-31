# Team Logger Analysis & Upgrade Proposal

**Date:** 2026-07-24  
**Source:** https://github.com/vi-k/team_logger  
**Purpose:** Extract patterns for upgrading diqit-logging với traceZone và structured logging

---

## 🎯 Key Patterns Learned

### 1. Zone-Based Trace Propagation

**Core Mechanism:**
```dart
// team_logger approach
T trace<T>(TraceId traceId, T Function() fn) =>
  runZoned(
    fn,
    zoneValues: {
      TraceId: [...zonedTraceIds(), traceId],  // Append to parent traces
      _tagsKey: {...zonedTags(), ...tags},      // Merge tags
    },
  );

// Retrieval from any nested call
static List<TraceId> zonedTraceIds([Zone? zone]) =>
  switch ((zone ?? Zone.current)[TraceId]) {
    final List<TraceId> list => list,
    _ => const <TraceId>[],
  };
```

**Benefits:**
- ✅ **Zero-parameter propagation** — không cần pass `traceId` qua 10 layers
- ✅ **Automatic capture** — mọi log call trong zone tự động inherit trace context
- ✅ **Nested traces** — support parent/child relationship (`[#payment-1, #retry-2]`)

**Use case trong Diqit:**
```dart
// KDS: Track order lifecycle
await DiqitLogger.trace(TraceId.auto('order-${order.id}'), () async {
  _orderBloc.add(AcceptOrder(order));      // logs with #order-123
  await _apiService.confirmOrder(order);   // logs with #order-123
  _soundService.playBump();                // logs with #order-123
});

// OT: Track sync operation
await DiqitLogger.trace(TraceId.auto('sync'), () async {
  final delta = await _apiClient.fetchDelta();  // #sync-1
  await _localDb.applyDelta(delta);             // #sync-1
  _syncBloc.add(SyncCompleted());               // #sync-1
});
```

---

### 2. TraceId Design Patterns

**3 factory constructors:**
```dart
sealed class TraceId {
  // Manual: Fixed group + num
  const factory TraceId.manual(String group, int num);
  
  // Auto: Group with lazy auto-increment
  factory TraceId.auto(String group, {int initial = 1});
  
  // Global: No group, global counter
  factory TraceId.global({int initial = 1});
}
```

**Lazy resolution:**
- Counter chỉ increment khi log level enabled
- Avoid wasting sequence numbers cho disabled logs

**Suffix support:**
```dart
final traceId = TraceId.auto('request');
log.i('Initial request', traceId: traceId);           // #request-1
log.w('Retry attempt', traceId: traceId.withSuffix('retry-2'));  // #request-1.retry-2
```

**Diqit use cases:**
```dart
// KDS: Bump order với retry logic
final traceId = TraceId.auto('bump-${item.id}');
DiqitLogger.i('Bumping item', traceId: traceId);
for (var i = 0; i < 3; i++) {
  DiqitLogger.w('Retry bump', traceId: traceId.withSuffix('retry-${i+1}'));
}

// Dispatch: Driver assignment attempts
final traceId = TraceId.auto('assign-driver');
DiqitLogger.i('Assigning driver to order ${order.id}', traceId: traceId);
// ... if failed
DiqitLogger.w('Fallback to zone 2', traceId: traceId.withSuffix('fallback'));
```

---

### 3. Hierarchical Logger (Namespace Pattern)

**createChild() pattern:**
```dart
final log = Logger('app');
final paymentLog = log.createChild(name: 'payment');   // path: 'app/payment'
final networkLog = paymentLog.createChild(name: 'network');  // path: 'app/payment/network'

// Logs automatically include full path
networkLog.i('Request sent');  // Output: [app/payment/network] Request sent
```

**Tag inheritance:**
```dart
final log = Logger('app', tags: {'global'});
final childLog = log.createChild(name: 'feature', tags: {'local'});
// childLog has tags: {'global', 'local'}
```

**Diqit adaptation:**
```dart
// Current: Flat structure
DiqitLogger.i('presentation.kds.order_grid.bump_order.started', message: 'Bumping');

// Proposed: Hierarchical
final kdsLogger = DiqitLogger.createChild('kds');
final orderGridLogger = kdsLogger.createChild('order_grid', tags: {LogTag.UI});
orderGridLogger.i('bump_order.started', message: 'Bumping');
// Output: [kds/order_grid] bump_order.started: Bumping #ui
```

---

### 4. Modular Layout System

**Row-based composition:**
```dart
ConsoleLogPrinter(
  rows: const [
    LogRow(
      children: [
        LogSequenceNum(),       // #123
        LogLevelName.short(),   // I
        LogTime.onlyTime(),     // 14:35:22
        LogPath(),              // app/payment
        LogTraceId(),           // #payment-1
        LogMessage(),           // Message text
      ],
      tail: [LogTags()],        // #http #request
    ),
  ],
)
```

**Customizable per component:**
- `LogSequenceNum()` — global incrementing counter
- `LogTime.onlyTime()` vs `LogTime.full()`
- `LogLevelName.short()` → "I" vs `.full()` → "INFO"
- `LogTraceId()` — displays all zone traces

**Diqit consideration:**
- Current: Fixed format trong `DiqitPrettyPrinter`
- Proposed: Allow per-app customization (KDS needs trace, OT doesn't)

---

## 🚀 Proposed Upgrade Path

### Phase 1: TraceId Infrastructure (Non-breaking)

**Files to create:**
- `lib/src/logger/trace_id.dart` — TraceId sealed class với 3 factories
- `lib/src/logger/zone_trace.dart` — Zone-based propagation utilities

**API additions (backward compatible):**
```dart
// New static method
class DiqitLogger {
  static Future<T> trace<T>(TraceId traceId, Future<T> Function() fn);
  static T traceSync<T>(TraceId traceId, T Function() fn);
}

// New optional parameter
static void info(
  String tag, {
  String? message,
  TraceId? traceId,  // ← NEW
  // ... existing params
});
```

**Migration strategy:**
- ✅ Existing code unchanged — `traceId` optional
- ✅ Teams adopt incrementally — wrap critical flows với `trace()`
- ✅ Filters support traceId — `LOG_TRACE=#payment-1`

---

### Phase 2: Hierarchical Loggers (Breaking, coordinated)

**Breaking change:**
```dart
// Before
DiqitLogger.info('presentation.kds.order_grid.bump_order.started');

// After
final logger = DiqitLogger.createChild('presentation')
  .createChild('kds')
  .createChild('order_grid');
logger.info('bump_order.started');
```

**Migration:**
1. Add `createChild()` API
2. Deprecate flat string tags (6-month window)
3. Provide codemod script for monorepo
4. Update AGENTS.md conventions

---

### Phase 3: Modular Layout (Per-app opt-in)

**Per-app printer configs:**
```dart
// KDS: Needs trace, timestamps, full detail
LoggerConfig.development(
  printer: ConsoleLogPrinter(
    rows: [
      LogRow(children: [
        LogSequenceNum(),
        LogTime.onlyTime(),
        LogPath(),
        LogTraceId(),      // ← KDS wants this
        LogMessage(),
      ]),
    ],
  ),
);

// Price Display: Minimal, no trace needed
LoggerConfig.production(
  printer: ConsoleLogPrinter(
    rows: [
      LogRow(children: [
        LogLevelName.short(),
        LogMessage(),      // ← Price Display wants minimal
      ]),
    ],
  ),
);
```

---

## 📊 Impact Analysis

### Cost vs Benefit

| Feature | Cost | Benefit | Priority |
|---------|------|---------|----------|
| **TraceId + Zone** | Low (non-breaking, 200 LOC) | High (zero-param trace propagation) | **P0** |
| **Hierarchical Logger** | High (breaking, monorepo-wide) | Medium (cleaner namespace, tag inheritance) | **P2** |
| **Modular Layout** | Medium (new API, per-app config) | Low (visual customization) | **P3** |

### Recommendation: Start with Phase 1

**Why:**
- ✅ Non-breaking — drop-in addition
- ✅ High value — solves "pass context through 10 layers" pain
- ✅ Low risk — existing code unaffected
- ✅ Incremental adoption — teams opt-in per feature

**Estimated effort:**
- TraceId implementation: 4 hours
- Zone propagation: 3 hours
- Tests: 2 hours
- Documentation + examples: 2 hours
- **Total: 11 hours (~1.5 days)**

---

## 🧪 Example Integration

### Before (Current Diqit)
```dart
// presentation/kds/order_grid_screen.dart
void _handleBump(OrderItem item) {
  DiqitLogger.info(
    'presentation.kds.order_grid.bump_order.started',
    message: 'Bumping item ${item.name}',
  );
  
  // Deep in domain layer
  final result = await _bumpUseCase.execute(item);  // No context!
  
  DiqitLogger.info(
    'presentation.kds.order_grid.bump_order.completed',
    message: 'Bumped successfully',
  );
}

// domain/use_cases/bump_use_case.dart
class BumpUseCase {
  Future<Either<Failure, Unit>> execute(OrderItem item) async {
    DiqitLogger.debug('???');  // What tag? What context?
    return _repository.bumpItem(item);
  }
}
```

**Pain point:** Mỗi layer phải manually construct tag path, không có link giữa logs.

---

### After (With TraceId + Zone)
```dart
// presentation/kds/order_grid_screen.dart
Future<void> _handleBump(OrderItem item) async {
  await DiqitLogger.trace(TraceId.auto('bump-${item.id}'), () async {
    DiqitLogger.info(
      'presentation.kds.order_grid',
      message: 'bump_order.started: ${item.name}',
    );  // Logs: [kds] bump_order.started: Pizza #bump-123
    
    final result = await _bumpUseCase.execute(item);
    
    DiqitLogger.info(
      'presentation.kds.order_grid',
      message: 'bump_order.completed',
    );  // Logs: [kds] bump_order.completed #bump-123
  });
}

// domain/use_cases/bump_use_case.dart
class BumpUseCase {
  Future<Either<Failure, Unit>> execute(OrderItem item) async {
    // No traceId parameter needed! Inherited from Zone
    DiqitLogger.debug(
      'domain.use_cases.bump',
      message: 'Executing bump logic',
    );  // Logs: [bump] Executing bump logic #bump-123
    
    return _repository.bumpItem(item);
  }
}
```

**Benefits:**
- ✅ All logs linked via `#bump-123`
- ✅ Zero parameters added — no boilerplate
- ✅ Filter logs: `LOG_TRACE=#bump-123` shows entire flow
- ✅ Nested traces: Payment flow can have `#order-456 > #payment-1 > #stripe-retry-2`

---

## 🔗 Related Docs

- **team_logger README:** https://github.com/vi-k/team_logger#readme
- **Dart Zone docs:** https://api.dart.dev/stable/dart-async/Zone-class.html
- **Current AGENTS.md:** `/Users/diqit/Documents/GitHub/phj/AGENTS.md` (DiqitLogger format)

---

**Next Steps:**
1. ✅ Analyze team_logger patterns (done)
2. ⏳ Prototype TraceId sealed class
3. ⏳ Implement Zone-based propagation
4. ⏳ Add tests for trace inheritance
5. ⏳ Update AGENTS.md với trace conventions
6. ⏳ Demo trong KDS: wrap order bump flow
