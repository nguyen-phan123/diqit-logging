import 'dart:async';

import 'package:diqit_logging/src/logger/trace_id.dart';
import 'package:diqit_logging/src/logger/zone_trace.dart';
import 'package:test/test.dart';

void main() {
  group('ZoneTrace', () {
    group('currentTrace()', () {
      test('returns null when no trace is active', () {
        expect(ZoneTrace.currentTrace(), isNull);
      });

      test('returns the active trace within runTraced', () async {
        final trace = TraceId.manual('test', 1);

        await ZoneTrace.runTraced(trace, () async {
          expect(ZoneTrace.currentTrace(), equals(trace));
        });
      });

      test('returns the most recent trace in nested zones', () async {
        final trace1 = TraceId.manual('outer', 1);
        final trace2 = TraceId.manual('inner', 2);

        await ZoneTrace.runTraced(trace1, () async {
          expect(ZoneTrace.currentTrace(), equals(trace1));

          await ZoneTrace.runTraced(trace2, () async {
            expect(ZoneTrace.currentTrace(), equals(trace2));
          });

          // Back to outer trace
          expect(ZoneTrace.currentTrace(), equals(trace1));
        });
      });

      test('preserves trace across async boundaries', () async {
        final trace = TraceId.manual('async', 1);

        await ZoneTrace.runTraced(trace, () async {
          expect(ZoneTrace.currentTrace(), equals(trace));

          await Future<void>.delayed(Duration(milliseconds: 10));
          expect(ZoneTrace.currentTrace(), equals(trace));

          await Future(() {
            expect(ZoneTrace.currentTrace(), equals(trace));
          });
        });
      });
    });

    group('currentTraceList()', () {
      test('returns empty list when no trace is active', () {
        expect(ZoneTrace.currentTraceList(), isEmpty);
      });

      test('returns single-element list for one trace', () async {
        final trace = TraceId.manual('test', 1);

        await ZoneTrace.runTraced(trace, () async {
          final list = ZoneTrace.currentTraceList();
          expect(list, hasLength(1));
          expect(list.first, equals(trace));
        });
      });

      test('returns full stack for nested traces', () async {
        final trace1 = TraceId.manual('outer', 1);
        final trace2 = TraceId.manual('middle', 2);
        final trace3 = TraceId.manual('inner', 3);

        await ZoneTrace.runTraced(trace1, () async {
          expect(ZoneTrace.currentTraceList(), equals([trace1]));

          await ZoneTrace.runTraced(trace2, () async {
            expect(ZoneTrace.currentTraceList(), equals([trace1, trace2]));

            await ZoneTrace.runTraced(trace3, () async {
              expect(
                ZoneTrace.currentTraceList(),
                equals([trace1, trace2, trace3]),
              );
            });
          });
        });
      });

      test('returns unmodifiable list', () async {
        final trace = TraceId.manual('test', 1);

        await ZoneTrace.runTraced(trace, () async {
          final list = ZoneTrace.currentTraceList();
          expect(() => list.add(TraceId.manual('evil', 2)), throwsUnsupportedError);
        });
      });
    });

    group('runTraced()', () {
      test('executes function and returns result', () async {
        final result = await ZoneTrace.runTraced(
          TraceId.manual('test', 1),
          () async => 42,
        );

        expect(result, equals(42));
      });

      test('propagates exceptions', () async {
        expect(
          () => ZoneTrace.runTraced(
            TraceId.manual('test', 1),
            () async => throw Exception('test error'),
          ),
          throwsException,
        );
      });

      test('isolates traces between parallel runs', () async {
        final trace1 = TraceId.manual('parallel', 1);
        final trace2 = TraceId.manual('parallel', 2);

        final results = await Future.wait([
          ZoneTrace.runTraced(trace1, () async {
            await Future<void>.delayed(Duration(milliseconds: 10));
            return ZoneTrace.currentTrace();
          }),
          ZoneTrace.runTraced(trace2, () async {
            await Future<void>.delayed(Duration(milliseconds: 10));
            return ZoneTrace.currentTrace();
          }),
        ]);

        expect(results[0], equals(trace1));
        expect(results[1], equals(trace2));
      });

      test('cleans up trace after completion', () async {
        final trace = TraceId.manual('cleanup', 1);

        expect(ZoneTrace.currentTrace(), isNull);

        await ZoneTrace.runTraced(trace, () async {
          expect(ZoneTrace.currentTrace(), equals(trace));
        });

        expect(ZoneTrace.currentTrace(), isNull);
      });
    });

    group('runTracedSync()', () {
      test('executes function synchronously and returns result', () {
        final result = ZoneTrace.runTracedSync(
          TraceId.manual('test', 1),
          () => 42,
        );

        expect(result, equals(42));
      });

      test('provides trace context within function', () {
        final trace = TraceId.manual('sync', 1);

        ZoneTrace.runTracedSync(trace, () {
          expect(ZoneTrace.currentTrace(), equals(trace));
        });
      });

      test('propagates exceptions', () {
        expect(
          () => ZoneTrace.runTracedSync(
            TraceId.manual('test', 1),
            () => throw Exception('test error'),
          ),
          throwsException,
        );
      });

      test('supports nested sync traces', () {
        final trace1 = TraceId.manual('outer', 1);
        final trace2 = TraceId.manual('inner', 2);

        ZoneTrace.runTracedSync(trace1, () {
          expect(ZoneTrace.currentTrace(), equals(trace1));

          ZoneTrace.runTracedSync(trace2, () {
            expect(ZoneTrace.currentTrace(), equals(trace2));
            expect(ZoneTrace.currentTraceList(), equals([trace1, trace2]));
          });

          expect(ZoneTrace.currentTrace(), equals(trace1));
        });
      });

      test('cleans up trace after completion', () {
        final trace = TraceId.manual('cleanup', 1);

        expect(ZoneTrace.currentTrace(), isNull);

        ZoneTrace.runTracedSync(trace, () {
          expect(ZoneTrace.currentTrace(), equals(trace));
        });

        expect(ZoneTrace.currentTrace(), isNull);
      });
    });
  });
}
