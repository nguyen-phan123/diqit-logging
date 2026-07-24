import 'dart:async';

import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('TraceZone', () {
    test('returns null when called outside any TraceZone', () {
      expect(TraceZone.currentTraceId, isNull);
      expect(DiqitLogger.currentTraceId, isNull);
    });

    test('propagates traceId across async boundaries', () async {
      const traceId = 't-test-1234';

      await DiqitLogger.runInTraceZone(() async {
        expect(TraceZone.currentTraceId, equals(traceId));
        expect(DiqitLogger.currentTraceId, equals(traceId));

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(TraceZone.currentTraceId, equals(traceId));

        final controller = StreamController<int>();
        final streamFuture = controller.stream.first.then((val) {
          expect(TraceZone.currentTraceId, equals(traceId));
          return val;
        });

        controller.add(42);
        await controller.close();
        final res = await streamFuture;
        expect(res, equals(42));
      }, traceId: traceId);

      expect(TraceZone.currentTraceId, isNull);
    });

    test('nested zone inherits parent traceId by default', () async {
      const parentTraceId = 't-parent-999';

      await DiqitLogger.runInTraceZone(() async {
        expect(DiqitLogger.currentTraceId, equals(parentTraceId));

        await DiqitLogger.runInTraceZone(() async {
          expect(DiqitLogger.currentTraceId, equals(parentTraceId));
        });
      }, traceId: parentTraceId);
    });

    test('runInNewTraceZone generates a fresh traceId', () async {
      const parentTraceId = 't-parent-111';

      await DiqitLogger.runInTraceZone(() async {
        expect(DiqitLogger.currentTraceId, equals(parentTraceId));

        await DiqitLogger.runInNewTraceZone(() async {
          expect(DiqitLogger.currentTraceId, isNotNull);
          expect(DiqitLogger.currentTraceId, isNot(equals(parentTraceId)));
        });

        expect(DiqitLogger.currentTraceId, equals(parentTraceId));
      }, traceId: parentTraceId);
    });
  });

  group('TraceEnvelope', () {
    test('extracts traceId from metadata envelope', () {
      final payload = {
        'meta': {'traceId': 't-socket-555'},
        'data': {'orderId': '101'}
      };

      final traceId = TraceEnvelope.extractTraceId(payload);
      expect(traceId, equals('t-socket-555'));
    });

    test('injects active traceId into outgoing payload', () {
      const activeTraceId = 't-outgoing-888';

      final result = TraceZone.runInTraceZone(
        () => TraceEnvelope.injectTraceId({'orderId': '202'}),
        traceId: activeTraceId,
      );

      expect(result['meta'], isA<Map<String, dynamic>>());
      final meta = result['meta'] as Map<String, dynamic>;
      expect(meta['traceId'], equals(activeTraceId));
      expect(result['orderId'], equals('202'));
    });
  });
}
