import 'package:diqit_logging/src/logger/trace_id.dart';
import 'package:test/test.dart';

void main() {
  group('TraceId', () {
    group('manual()', () {
      test('creates trace with explicit group and num', () {
        final trace = TraceId.manual('payment', 42);
        expect(trace.toString(), equals('#payment-42'));
      });

      test('supports suffix', () {
        final trace = TraceId.manual('payment', 42).withSuffix('retry');
        expect(trace.toString(), equals('#payment-42.retry'));
      });

      test('equality works correctly', () {
        final trace1 = TraceId.manual('payment', 42);
        final trace2 = TraceId.manual('payment', 42);
        final trace3 = TraceId.manual('payment', 43);

        expect(trace1, equals(trace2));
        expect(trace1, isNot(equals(trace3)));
      });

      test('equality includes suffix', () {
        final trace1 = TraceId.manual('payment', 42).withSuffix('retry');
        final trace2 = TraceId.manual('payment', 42).withSuffix('retry');
        final trace3 = TraceId.manual('payment', 42).withSuffix('fallback');

        expect(trace1, equals(trace2));
        expect(trace1, isNot(equals(trace3)));
      });
    });

    group('auto()', () {
      test('creates trace with auto-incrementing counter per group', () {
        final trace1 = TraceId.auto('sync');
        final trace2 = TraceId.auto('sync');
        final trace3 = TraceId.auto('payment');

        // Force resolution by calling toString()
        final id1 = trace1.toString();
        final id2 = trace2.toString();
        final id3 = trace3.toString();

        // Each group has independent counter
        expect(id1, matches(r'^#sync-\d+$'));
        expect(id2, matches(r'^#sync-\d+$'));
        expect(id3, matches(r'^#payment-\d+$'));

        // Extract numbers
        final num1 = int.parse(id1.split('-')[1]);
        final num2 = int.parse(id2.split('-')[1]);
        final num3 = int.parse(id3.split('-')[1]);

        // sync counter increments
        expect(num2, equals(num1 + 1));

        // payment counter starts fresh
        expect(num3, equals(1));
      });

      test('lazy resolution - counter only increments when accessed', () {
        final trace1 = TraceId.auto('lazy');
        final trace2 = TraceId.auto('lazy');

        // Before toString(), counters not resolved
        // After first toString(), trace1 gets next number
        final id1 = trace1.toString();
        final num1 = int.parse(id1.split('-')[1]);

        // trace2 gets next number
        final id2 = trace2.toString();
        final num2 = int.parse(id2.split('-')[1]);

        expect(num2, equals(num1 + 1));

        // Repeated toString() returns same value
        expect(trace1.toString(), equals(id1));
        expect(trace2.toString(), equals(id2));
      });

      test('supports suffix', () {
        final trace = TraceId.auto('sync').withSuffix('retry');
        expect(trace.toString(), matches(r'^#sync-\d+\.retry$'));
      });

      test('equality works correctly', () {
        final trace1 = TraceId.auto('test');
        final trace2 = TraceId.auto('test');

        // Force resolution
        trace1.toString();
        trace2.toString();

        // Different counter values
        expect(trace1, isNot(equals(trace2)));

        // Same instance equals itself
        expect(trace1, equals(trace1));
      });
    });

    group('global()', () {
      test('creates trace with shared global counter', () {
        final trace1 = TraceId.global();
        final trace2 = TraceId.global();

        final id1 = trace1.toString();
        final id2 = trace2.toString();

        expect(id1, matches(r'^#\d+$'));
        expect(id2, matches(r'^#\d+$'));

        final num1 = int.parse(id1.substring(1));
        final num2 = int.parse(id2.substring(1));

        expect(num2, equals(num1 + 1));
      });

      test('supports suffix', () {
        final trace = TraceId.global().withSuffix('retry');
        expect(trace.toString(), matches(r'^#\d+\.retry$'));
      });

      test('lazy resolution works', () {
        final trace1 = TraceId.global();
        final trace2 = TraceId.global();

        // Force resolution
        final id1 = trace1.toString();
        final id2 = trace2.toString();

        // Repeated calls return same value
        expect(trace1.toString(), equals(id1));
        expect(trace2.toString(), equals(id2));
      });

      test('equality works correctly', () {
        final trace1 = TraceId.global();
        final trace2 = TraceId.global();

        // Force resolution
        trace1.toString();
        trace2.toString();

        // Different counter values
        expect(trace1, isNot(equals(trace2)));

        // Same instance equals itself
        expect(trace1, equals(trace1));
      });
    });

    group('withSuffix()', () {
      test('preserves group and num for manual trace', () {
        final base = TraceId.manual('payment', 42);
        final retry = base.withSuffix('retry');

        expect(base.toString(), equals('#payment-42'));
        expect(retry.toString(), equals('#payment-42.retry'));
      });

      test('preserves resolved num for auto trace', () {
        final base = TraceId.auto('sync');
        final baseId = base.toString(); // Force resolution

        final retry = base.withSuffix('retry');
        final retryId = retry.toString();

        final baseNum = int.parse(baseId.split('-')[1]);
        final retryNum = int.parse(retryId.split('-')[1].split('.')[0]);

        expect(retryNum, equals(baseNum));
        expect(retryId, endsWith('.retry'));
      });

      test('preserves resolved num for global trace', () {
        final base = TraceId.global();
        final baseId = base.toString(); // Force resolution

        final retry = base.withSuffix('retry');
        final retryId = retry.toString();

        final baseNum = int.parse(baseId.substring(1));
        final retryNum = int.parse(retryId.substring(1).split('.')[0]);

        expect(retryNum, equals(baseNum));
        expect(retryId, endsWith('.retry'));
      });

      test('chaining suffixes replaces previous suffix', () {
        final base = TraceId.manual('payment', 42);
        final retry = base.withSuffix('retry');
        final fallback = retry.withSuffix('fallback');

        expect(base.toString(), equals('#payment-42'));
        expect(retry.toString(), equals('#payment-42.retry'));
        expect(fallback.toString(), equals('#payment-42.fallback'));
      });
    });
  });
}
