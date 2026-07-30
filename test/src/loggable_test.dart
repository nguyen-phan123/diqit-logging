// ignore_for_file: prefer_const_constructors, deprecated_member_use_from_same_package
import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

// Test entity implementing Loggable
class TestOrder with Loggable {
  final String id;
  final double total;
  final int itemCount;

  TestOrder({
    required this.id,
    required this.total,
    required this.itemCount,
  });

  @override
  Map<String, dynamic> toLoggableMap() => {
        'id': id,
        'total': '\$${total.toStringAsFixed(2)}',
        'item_count': itemCount,
      };
}

// Nested Loggable entity
class TestCustomer with Loggable {
  final String name;
  final TestOrder? lastOrder;

  TestCustomer({required this.name, this.lastOrder});

  @override
  Map<String, dynamic> toLoggableMap() => {
        'name': name,
        if (lastOrder != null) 'last_order': lastOrder,
      };
}

void main() {
  group('Loggable Mixin', () {
    setUp(() async {
      await DiqitLogger.initialize(LoggerConfig.development());
    });

    test('logs simple Loggable object with key-value format', () {
      final order = TestOrder(id: 'ORD-123', total: 45.99, itemCount: 3);

      DiqitLogger.i('Order created', data: order);

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('Order created'));
      expect(logOutput, contains('"id"'));
      expect(logOutput, contains('"ORD-123"'));
      expect(logOutput, contains('"total"'));
      expect(logOutput, contains(r'$45.99'));
      expect(logOutput, contains('"item_count"'));
      expect(logOutput, contains('3'));
    });

    test('logs nested Loggable objects', () {
      final order = TestOrder(id: 'ORD-456', total: 100, itemCount: 5);
      final customer = TestCustomer(name: 'John Doe', lastOrder: order);

      DiqitLogger.i('Customer profile', data: customer);

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('Customer profile'));
      expect(logOutput, contains('name'));
      expect(logOutput, contains('John Doe'));
      expect(logOutput, contains('last_order'));
      expect(logOutput, contains('ORD-456'));
    });

    test('handles Loggable with null nested object', () {
      final customer = TestCustomer(name: 'Jane Doe', lastOrder: null);

      DiqitLogger.i('New customer', data: customer);

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('New customer'));
      expect(logOutput, contains('name'));
      expect(logOutput, contains('Jane Doe'));
      expect(logOutput, isNot(contains('last_order')));
    });

    test('falls back to JSON for non-Loggable objects without converter', () {
      DiqitLogger.typeConverterRegistry.clear();

      final plainObject = DateTime(2024, 1, 1);

      DiqitLogger.i('Plain object', data: plainObject);

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('Plain object'));
      expect(logOutput, contains('"data"'));
      expect(logOutput, isNotEmpty);
    });

    test('handles empty Loggable map', () {
      final emptyEntity = _EmptyLoggable();

      DiqitLogger.i('Empty entity', data: emptyEntity);

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('Empty entity'));
      expect(logOutput, contains('{}'));
    });

    test('works with all log levels', () {
      final order = TestOrder(id: 'ORD-789', total: 25, itemCount: 1);

      DiqitLogger.d('Debug order', data: order);
      DiqitLogger.i('Info order', data: order);
      DiqitLogger.w('Warning order', data: order);
      DiqitLogger.e('Error order', data: order);

      final history = DiqitLogger.getLogHistory();
      expect(history.length, greaterThanOrEqualTo(4));

      for (final log in history.takeLast(4)) {
        final output = log.lines.join('\n');
        expect(output, contains('ORD-789'));
      }
    });
  });
}

class _EmptyLoggable with Loggable {
  @override
  Map<String, dynamic> toLoggableMap() => {};
}

extension _TakeLast<T> on Iterable<T> {
  List<T> takeLast(int count) {
    final list = toList();
    if (list.length <= count) return list;
    return list.sublist(list.length - count);
  }
}
