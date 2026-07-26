import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('Trace Propagation Integration', () {
    setUp(() async {
      await DiqitLogger.initialize(LoggerConfig.development());
    });

    test('manual trace propagates through async boundaries', () async {
      await DiqitLogger.runTraced(
        TraceId.manual('login', 1001),
        () async {
          DiqitLogger.i('Step 1: Validate credentials');
          await Future<void>.delayed(Duration(milliseconds: 10));
          DiqitLogger.i('Step 2: Create session');
          await Future<void>.delayed(Duration(milliseconds: 10));
          DiqitLogger.i('Step 3: Login complete');
        },
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      // Find lines containing our messages
      final step1Lines = logLines.where((l) => l.contains('Step 1: Validate credentials')).toList();
      final step2Lines = logLines.where((l) => l.contains('Step 2: Create session')).toList();
      final step3Lines = logLines.where((l) => l.contains('Step 3: Login complete')).toList();

      expect(step1Lines.isNotEmpty, true);
      expect(step2Lines.isNotEmpty, true);
      expect(step3Lines.isNotEmpty, true);

      // All should contain the trace ID
      expect(step1Lines.any((l) => l.contains('[#login-1001]')), true);
      expect(step2Lines.any((l) => l.contains('[#login-1001]')), true);
      expect(step3Lines.any((l) => l.contains('[#login-1001]')), true);
    });

    test('auto trace generates unique IDs', () async {
      await DiqitLogger.runTraced(
        TraceId.auto('req'),
        () async {
          DiqitLogger.d('Request 1 started');
        },
      );

      await DiqitLogger.runTraced(
        TraceId.auto('req'),
        () async {
          DiqitLogger.d('Request 2 started');
        },
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      final req1Lines = logLines.where((l) => l.contains('Request 1 started')).toList();
      final req2Lines = logLines.where((l) => l.contains('Request 2 started')).toList();

      expect(req1Lines.isNotEmpty, true);
      expect(req2Lines.isNotEmpty, true);

      // Both should have req- prefix but different numbers
      expect(req1Lines.any((l) => l.contains('[#req-')), true);
      expect(req2Lines.any((l) => l.contains('[#req-')), true);

      // Extract trace IDs and verify they're different
      final trace1 = _extractTraceId(req1Lines.first);
      final trace2 = _extractTraceId(req2Lines.first);
      expect(trace1, isNot(equals(trace2)));
    });

    test('nested traces append to stack', () async {
      await DiqitLogger.runTraced(
        TraceId.manual('outer', 1),
        () async {
          DiqitLogger.i('Outer scope');

          await DiqitLogger.runTraced(
            TraceId.manual('inner', 2),
            () async {
              DiqitLogger.i('Inner scope');
            },
          );

          DiqitLogger.i('Back to outer');
        },
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      final outerLines = logLines.where((l) => l.contains('Outer scope')).toList();
      final innerLines = logLines.where((l) => l.contains('Inner scope')).toList();
      final backLines = logLines.where((l) => l.contains('Back to outer')).toList();

      expect(outerLines.any((l) => l.contains('[#outer-1]')), true);
      expect(innerLines.any((l) => l.contains('[#outer-1 > #inner-2]')), true);
      expect(backLines.any((l) => l.contains('[#outer-1]')), true);
    });

    test('explicit traceId overrides zone trace', () async {
      await DiqitLogger.runTraced(
        TraceId.manual('zone', 100),
        () async {
          DiqitLogger.i('Uses zone trace');
          DiqitLogger.i('Override with explicit', traceId: TraceId.manual('explicit', 200));
          DiqitLogger.i('Back to zone trace');
        },
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      final zoneLine1 = logLines.where((l) => l.contains('Uses zone trace')).toList();
      final explicitLine = logLines.where((l) => l.contains('Override with explicit')).toList();
      final zoneLine2 = logLines.where((l) => l.contains('Back to zone trace')).toList();

      expect(zoneLine1.any((l) => l.contains('[#zone-100]')), true);
      expect(explicitLine.any((l) => l.contains('[#explicit-200]')), true);
      expect(zoneLine2.any((l) => l.contains('[#zone-100]')), true);
    });

    test('runTracedSync works for synchronous code', () {
      DiqitLogger.runTracedSync(
        TraceId.manual('sync', 1),
        () {
          DiqitLogger.d('Sync step 1');
          DiqitLogger.d('Sync step 2');
        },
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      final step1Lines = logLines.where((l) => l.contains('Sync step 1')).toList();
      final step2Lines = logLines.where((l) => l.contains('Sync step 2')).toList();

      expect(step1Lines.any((l) => l.contains('[#sync-1]')), true);
      expect(step2Lines.any((l) => l.contains('[#sync-1]')), true);
    });

    test('trace with suffix', () async {
      await DiqitLogger.runTraced(
        TraceId.manual('order', 12345).withSuffix('retry'),
        () async {
          DiqitLogger.i('Processing order');
        },
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      final orderLines = logLines.where((l) => l.contains('Processing order')).toList();
      expect(orderLines.any((l) => l.contains('[#order-12345.retry]')), true);
    });

    test('real-world scenario: KDS bump flow', () async {
      // Simulate KDS bump order flow from PRD user story
      // Uses context for entity ID, keeping trace ID pure for operation filtering
      await DiqitLogger.runTraced(
        TraceId.manual('bump', 001),
        () async {
          DiqitLogger.i('Bump initiated', tag: LogTag.custom('kds.bump'));

          // Simulate socket emit
          await Future<void>.delayed(Duration(milliseconds: 5));
          DiqitLogger.d('Socket: emit bump_order', tag: LogTag.custom('socket'));

          // Simulate API call
          await Future<void>.delayed(Duration(milliseconds: 10));
          DiqitLogger.d('API: POST /orders/bump', tag: LogTag.custom('api'));

          // Simulate UI update
          DiqitLogger.i('UI: Order removed from grid', tag: LogTag.custom('ui'));
        },
        context: {'order_id': 'ORD-001'},
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      // All logs should have same trace ID
      final bumpLines = logLines.where((l) =>
        l.contains('Bump initiated') ||
        l.contains('Socket: emit bump_order') ||
        l.contains('API: POST /orders/bump') ||
        l.contains('UI: Order removed from grid')
      ).toList();

      expect(bumpLines.length >= 4, true);
      for (final line in bumpLines) {
        expect(line.contains('[#bump-1]'), true);
        expect(line.contains('"order_id":"ORD-001"'), true);
      }
    });

    test('global trace affects all logs', () async {
      await DiqitLogger.runTraced(
        TraceId.global(),
        () async {
          DiqitLogger.i('Log 1');
          DiqitLogger.i('Log 2');

          // Even logs outside explicit trace block inherit global
          await Future<void>.delayed(Duration(milliseconds: 5));
          DiqitLogger.i('Log 3');
        },
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();

      final log1Lines = logLines.where((l) => l.contains('Log 1')).toList();
      final log2Lines = logLines.where((l) => l.contains('Log 2')).toList();
      final log3Lines = logLines.where((l) => l.contains('Log 3')).toList();

      // All should have same global counter value
      final traceId = _extractTraceId(log1Lines.first);
      expect(traceId.isNotEmpty, true);

      expect(log1Lines.any((l) => l.contains('[$traceId]')), true);
      expect(log2Lines.any((l) => l.contains('[$traceId]')), true);
      expect(log3Lines.any((l) => l.contains('[$traceId]')), true);
    });

    test('context filter: entity-based query independent of trace', () async {
      // Operation A: bump order ORD-001
      await DiqitLogger.runTraced(
        TraceId.manual('bump', 1),
        () async {
          DiqitLogger.i('Bump order', tag: LogTag.kds);
        },
        context: {'order_id': 'ORD-001'},
      );

      // Operation B: cancel order ORD-001 (different trace, same entity)
      await DiqitLogger.runTraced(
        TraceId.manual('cancel', 2),
        () async {
          DiqitLogger.i('Cancel order', tag: LogTag.order);
        },
        context: {'order_id': 'ORD-001'},
      );

      // Operation C: bump different order ORD-002
      await DiqitLogger.runTraced(
        TraceId.manual('bump', 3),
        () async {
          DiqitLogger.i('Bump another order', tag: LogTag.kds);
        },
        context: {'order_id': 'ORD-002'},
      );

      // Filter by entity: should find both operation A and B, but not C
      final ord001Logs = DiqitLogger.getLogHistoryByContext(
        'order_id',
        'ORD-001',
      );
      final ord001Lines = ord001Logs.expand((e) => e.lines).toList();
      expect(ord001Lines.any((l) => l.contains('Bump order')), true);
      expect(ord001Lines.any((l) => l.contains('Cancel order')), true);
      expect(ord001Lines.any((l) => l.contains('Bump another order')), false);

      // Filter by operation: should find both bump operations
      final bumpLogs = DiqitLogger.getLogHistoryForTrace('#bump-1');
      final bumpLines1 = bumpLogs.expand((e) => e.lines).toList();
      expect(
        bumpLines1.any((l) => l.contains('Bump order')),
        true,
      );
    });
  });

  group('Hierarchical Logger', () {
    setUp(() async {
      await DiqitLogger.initialize(LoggerConfig.development());
    });

    test('createChild produces namespace path in output', () {
      final kdsLogger = DiqitLogger.createChild('kds');
      kdsLogger.i('hierarchical_child_path_KDS_started');

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();
      final kdsLine = logLines.firstWhere(
        (l) => l.contains('hierarchical_child_path_KDS_started'),
        orElse: () => '',
      );
      expect(kdsLine, contains('[kds]'));
      expect(kdsLine, contains('hierarchical_child_path_KDS_started'));
    });

    test('nested createChild produces slash-delimited path', () {
      final kdsLogger = DiqitLogger.createChild('kds');
      final gridLogger = kdsLogger.createChild('order_grid');
      gridLogger.d('hierarchical_nested_path_test');

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();
      final bumpLine = logLines.firstWhere(
        (l) => l.contains('hierarchical_nested_path_test'),
        orElse: () => '',
      );
      expect(bumpLine, contains('[kds/order_grid]'));
    });

    test('root logger without createChild has no path', () {
      DiqitLogger.i('root_log_no_path_unique_msg');

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();
      final rootLine = logLines.firstWhere(
        (l) => l.contains('root_log_no_path_unique_msg'),
        orElse: () => '',
      );

      expect(rootLine.contains('[kds/'), false);
      expect(rootLine.contains('root_log_no_path_unique_msg'), true);
    });

    test('createChild with trace and context', () async {
      final kdsLogger = DiqitLogger.createChild('kds');
      await DiqitLogger.runTraced(
        TraceId.manual('bump', 1),
        () async {
          kdsLogger.i('child_path_trace_ctx_test', tag: LogTag.custom('kds.bump'));
        },
        context: {'order_id': 'ORD-001'},
      );

      final logs = DiqitLogger.getLogHistory();
      final logLines = logs.expand((e) => e.lines).toList();
      final bumpLine = logLines.firstWhere(
        (l) => l.contains('child_path_trace_ctx_test'),
        orElse: () => '',
      );
      expect(bumpLine, contains('[kds.bump]'));
      expect(bumpLine, contains('[kds]'));
      expect(bumpLine, contains('[#bump-1]'));
      expect(bumpLine, contains('"order_id":"ORD-001"'));
    });
  });
}

/// Extract trace ID from log line (format: [trace-id])
String _extractTraceId(String logLine) {
  // Strip ANSI color codes first
  final stripped = logLine.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

  // Match trace ID pattern: [#word-number], [#number], or [#word-number > #word-number]
  // Skip timestamp brackets like [11:46:22] by excluding colons
  final match = RegExp(r'\[(#?[a-z0-9][\w\-\s>\.]*)\]', caseSensitive: false).firstMatch(stripped);
  return match?.group(1) ?? '';
}
