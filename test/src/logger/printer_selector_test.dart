import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('PrinterSelector', () {
    late PrinterSelector selector;
    late DPrettyPrinter minimalPrinter;
    late DPrettyPrinter tracePrinter;
    late DPrettyPrinter customPrinter;

    setUp(() {
      minimalPrinter = DPrettyPrinter.minimal();
      tracePrinter = DPrettyPrinter.trace();
      customPrinter = DPrettyPrinter.compact();
      selector = PrinterSelector(
        minimalPrinter: minimalPrinter,
        tracePrinter: tracePrinter,
      );
    });

    test('should return custom printer when provided', () {
      final result = selector.select(
        isShorthand: true,
        customPrinter: customPrinter,
      );
      expect(result, equals(customPrinter));
    });

    test('should return minimal printer for shorthand methods', () {
      final result = selector.select(isShorthand: true);
      expect(result, equals(minimalPrinter));
    });

    test('should return ephemeral printer when countMethod is provided', () {
      final result = selector.select(
        isShorthand: false,
        countMethod: 5,
      );
      // Ephemeral printer is created on-demand, so we just verify it's not null
      expect(result, isNotNull);
      expect(result, isNot(equals(tracePrinter)));
      expect(result, isNot(equals(minimalPrinter)));
    });

    test('should return trace printer for full methods without countMethod', () {
      final result = selector.select(isShorthand: false);
      expect(result, equals(tracePrinter));
    });

    test('custom printer overrides shorthand flag', () {
      final result = selector.select(
        isShorthand: true,
        customPrinter: customPrinter,
      );
      expect(result, equals(customPrinter));
    });

    test('custom printer overrides countMethod', () {
      final result = selector.select(
        isShorthand: false,
        countMethod: 10,
        customPrinter: customPrinter,
      );
      expect(result, equals(customPrinter));
    });
  });
}
