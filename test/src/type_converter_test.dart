// ignore_for_file: prefer_const_constructors, deprecated_member_use_from_same_package
import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('TypeConverterRegistry', () {
    late TypeConverterRegistry registry;

    setUp(() {
      registry = TypeConverterRegistry();
    });

    test('registers and uses converter for custom type', () {
      registry.register<DateTime>((dt) => dt.toIso8601String());

      final now = DateTime(2024, 1, 15, 10, 30);
      final result = registry.convert(now);

      expect(result, equals('2024-01-15T10:30:00.000'));
    });

    test('returns null for unregistered type', () {
      final result = registry.convert('unregistered');

      expect(result, isNull);
    });

    test('replaces existing converter for same type', () {
      registry.register<DateTime>((dt) => 'first');
      registry.register<DateTime>((dt) => 'second');

      final now = DateTime.now();
      final result = registry.convert(now);

      expect(result, equals('second'));
    });

    test('unregister removes converter', () {
      registry.register<DateTime>((dt) => dt.toIso8601String());

      final removed = registry.unregister<DateTime>();
      expect(removed, isTrue);

      final result = registry.convert(DateTime.now());
      expect(result, isNull);
    });

    test('unregister returns false for non-existent converter', () {
      final removed = registry.unregister<String>();
      expect(removed, isFalse);
    });

    test('supports multiple types simultaneously', () {
      registry.register<DateTime>((dt) => dt.toIso8601String());
      registry.register<Duration>((d) => '${d.inSeconds}s');
      registry.register<Uri>((uri) => uri.toString());

      expect(
        registry.convert(DateTime(2024, 1, 1)),
        equals('2024-01-01T00:00:00.000'),
      );
      expect(registry.convert(Duration(seconds: 42)), equals('42s'));
      expect(
        registry.convert(Uri.parse('https://example.com')),
        equals('https://example.com'),
      );
    });

    test('converter can access full object state', () {
      registry.register<Duration>((d) {
        if (d.inSeconds < 60) return '${d.inSeconds}s';
        if (d.inMinutes < 60) return '${d.inMinutes}m';
        return '${d.inHours}h';
      });

      expect(registry.convert(Duration(seconds: 30)), equals('30s'));
      expect(registry.convert(Duration(minutes: 5)), equals('5m'));
      expect(registry.convert(Duration(hours: 2)), equals('2h'));
    });
  });

  group('DiqitLogger.registerConverter', () {
    setUp(() async {
      await DiqitLogger.initialize(LoggerConfig.development());
      // Clear any converters from previous tests
      DiqitLogger.typeConverterRegistry.clear();
    });

    test('uses registered converter when logging object', () {
      DiqitLogger.registerConverter<DateTime>(
        (dt) => dt.toIso8601String(),
      );

      final testDate = DateTime(2024, 7, 26, 14, 30);
      DiqitLogger.i('Event scheduled', data: testDate);

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('Event scheduled'));
      expect(logOutput, contains('"2024-07-26T14:30:00.000"'));
    });

    test('uses registered Duration converter', () {
      DiqitLogger.registerConverter<Duration>(
        (d) => '${d.inSeconds}s',
      );

      DiqitLogger.i('Operation took', data: Duration(seconds: 42));

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('"42s"'));
    });

    test('Loggable takes precedence over TypeConverter', () {
      // Register converter for TestLoggable (shouldn't be used)
      DiqitLogger.registerConverter<_TestLoggable>(
        (obj) => 'FROM_CONVERTER',
      );

      final obj = _TestLoggable('test-value');
      DiqitLogger.i('Object logged', data: obj);

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should use Loggable.toLoggableMap, not converter
      expect(logOutput, contains('value'));
      expect(logOutput, contains('test-value'));
      expect(logOutput, isNot(contains('FROM_CONVERTER')));
    });

    test('TypeConverter used when object is not Loggable', () {
      DiqitLogger.registerConverter<Uri>(
        (uri) => uri.host,
      );

      DiqitLogger.i('API endpoint',
          data: Uri.parse('https://api.example.com/v1'));

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('"api.example.com"'));
    });

    test('unregisterConverter removes converter', () {
      DiqitLogger.registerConverter<DateTime>(
        (dt) => dt.toIso8601String(),
      );

      final removed = DiqitLogger.unregisterConverter<DateTime>();
      expect(removed, isTrue);

      // Should fall back to toString
      DiqitLogger.i('Date', data: DateTime(2024, 1, 1));

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Won't be ISO format anymore, will be JSON-encoded
      expect(logOutput, contains('Date'));
      expect(logOutput, isNot(contains('2024-01-01T00:00:00.000')));
    });

    test('multiple converters work independently', () {
      DiqitLogger.registerConverter<DateTime>(
        (dt) => dt.toIso8601String(),
      );
      DiqitLogger.registerConverter<Duration>(
        (d) => '${d.inMilliseconds}ms',
      );

      DiqitLogger.i('Time', data: DateTime(2024, 1, 1));
      DiqitLogger.i('Duration', data: Duration(milliseconds: 500));

      final history = DiqitLogger.getLogHistory();
      final timeLog = history[history.length - 2].lines.join('\n');
      final durationLog = history.last.lines.join('\n');

      expect(timeLog, contains('2024-01-01T00:00:00.000'));
      expect(durationLog, contains('500ms'));
    });
  });
}

class _TestLoggable with Loggable {
  final String value;
  _TestLoggable(this.value);

  @override
  Map<String, dynamic> toLoggableMap() => {'value': value};
}
