import 'dart:async';

import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('ZoneTrace', () {
    test('returns null when called outside any trace zone', () {
      expect(ZoneTrace.currentTrace(), isNull);
      expect(DiqitLogger.currentTraceId, isNull);
    });

    test('propagates trace across async boundaries', () async {
      final trace = TraceId.manual('test', 1234);

      await DiqitLogger.runTraced(trace, () async {
        expect(ZoneTrace.currentTrace(), equals(trace));
        expect(DiqitLogger.currentTraceId, equals(trace));

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(ZoneTrace.currentTrace(), equals(trace));

        final controller = StreamController<int>();
        final streamFuture = controller.stream.first.then((val) {
          expect(ZoneTrace.currentTrace(), equals(trace));
          return val;
        });

        controller.add(42);
        await controller.close();
        final res = await streamFuture;
        expect(res, equals(42));
      });

      expect(ZoneTrace.currentTrace(), isNull);
    });

    test('nested traces create stack', () async {
      final parent = TraceId.manual('parent', 999);
      final child = TraceId.manual('child', 1);

      await DiqitLogger.runTraced(parent, () async {
        expect(ZoneTrace.currentTrace(), equals(parent));

        await DiqitLogger.runTraced(child, () async {
          // Innermost trace is the child
          expect(ZoneTrace.currentTrace(), equals(child));
          // Full stack has both parent and child
          final stack = ZoneTrace.currentTraceList();
          expect(stack.length, equals(2));
          expect(stack[0], equals(parent));
          expect(stack[1], equals(child));
        });

        // Back to parent trace
        expect(ZoneTrace.currentTrace(), equals(parent));
      });
    });

    test('global trace IDs auto-increment', () {
      final t1 = TraceId.global();
      final t2 = TraceId.global();
      expect(t1.toString(), isNot(equals(t2.toString())));
    });

    test('intercepts uncaught errors with trace context via ZoneTrace', () async {
      final trace = TraceId.manual('error', 500);
      Object? capturedError;
      StackTrace? capturedStack;
      TraceId? capturedTrace;

      ZoneTrace.onError = (error, stackTrace, traceId) {
        capturedError = error;
        capturedStack = stackTrace;
        capturedTrace = traceId;
      };

      try {
        await ZoneTrace.runTraced(
          trace,
          () async => throw Exception('Test crash'),
        );
      } catch (_) {}

      expect(capturedError, isA<Exception>());
      expect(
        capturedError.toString(),
        contains('Test crash'),
      );
      expect(capturedStack, isNotNull);
      expect(capturedTrace, equals(trace));

      ZoneTrace.onError = null;
    });

    test('intercepts uncaught errors via DiqitLogger.runTraced', () async {
      await DiqitLogger.initialize(LoggerConfig.development());
      final trace = TraceId.manual('diqit-err', 501);

      try {
        await DiqitLogger.runTraced(
          trace,
          () async => throw StateError('Async crash'),
        );
      } catch (_) {}

      final history = DiqitLogger.getLogHistoryForTrace(trace.toString());
      expect(history, isNotEmpty);

      final logLines = history.expand((e) => e.lines).toList();
      final errorLine = logLines.firstWhere(
        (l) => l.contains('Uncaught error') && l.contains('#diqit-err-501'),
        orElse: () => '',
      );
      expect(errorLine, isNotEmpty);
    });
  });

  group('ZoneTrace Metadata Transport', () {
    test('extracts traceId from metadata envelope', () {
      final payload = {
        'meta': {'traceId': 't-socket-555'},
        'data': {'orderId': '101'}
      };

      final traceId = ZoneTrace.extractTraceId(payload);
      expect(traceId, equals('t-socket-555'));
    });

    test('injects active traceId into outgoing payload', () {
      final trace = TraceId.manual('outgoing', 888);

      final result = ZoneTrace.runTracedSync(
        trace,
        () => ZoneTrace.injectTraceId({'orderId': '202'}),
      );

      expect(result['meta'], isA<Map<String, dynamic>>());
      final meta = result['meta'] as Map<String, dynamic>;
      expect(meta['traceId'], equals(trace.toString()));
      expect(result['orderId'], equals('202'));
    });
  });
}
