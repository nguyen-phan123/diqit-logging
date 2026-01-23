import 'package:diqit_logging/diqit_logging.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  group('AlignedPrettyPrinter', () {
    test('adds padding to log output', () {
      final basePrinter = DPrettyPrinter.minimal();
      final alignedPrinter = AlignedPrettyPrinter(basePrinter, paddingSize: 3);

      final event = LogEvent(
        Level.info,
        'Test message',
        error: null,
        stackTrace: null,
      );

      final result = alignedPrinter.log(event);

      expect(result, isNotEmpty);
      // Every line should start with 3 spaces
      for (final line in result) {
        expect(line.startsWith('   '), isTrue);
      }
    });

    test('handles zero padding', () {
      final basePrinter = DPrettyPrinter.minimal();
      final alignedPrinter = AlignedPrettyPrinter(basePrinter, paddingSize: 0);

      final event = LogEvent(
        Level.info,
        'Test message',
        error: null,
        stackTrace: null,
      );

      final result = alignedPrinter.log(event);

      expect(result, isNotEmpty);
      // No padding should be added
      for (final line in result) {
        expect(line.startsWith(' '), isFalse);
      }
    });

    test('handles custom padding size', () {
      final basePrinter = DPrettyPrinter.minimal();
      final alignedPrinter = AlignedPrettyPrinter(basePrinter, paddingSize: 5);

      final event = LogEvent(
        Level.info,
        'Test message',
        error: null,
        stackTrace: null,
      );

      final result = alignedPrinter.log(event);

      expect(result, isNotEmpty);
      // Every line should start with 5 spaces
      for (final line in result) {
        expect(line.startsWith('     '), isTrue);
      }
    });

    test('minimalAligned factory creates aligned printer', () {
      final printer = DPrettyPrinter.minimalAligned();

      expect(printer, isA<AlignedPrettyPrinter>());

      final event = LogEvent(
        Level.info,
        'Test message',
        error: null,
        stackTrace: null,
      );

      final result = printer.log(event);

      expect(result, isNotEmpty);
      // Default padding should be 3
      for (final line in result) {
        expect(line.startsWith('   '), isTrue);
      }
    });

    test('minimalAligned with custom padding', () {
      final printer = DPrettyPrinter.minimalAligned(paddingSize: 4);

      final event = LogEvent(
        Level.info,
        'Test message',
        error: null,
        stackTrace: null,
      );

      final result = printer.log(event);

      expect(result, isNotEmpty);
      for (final line in result) {
        expect(line.startsWith('    '), isTrue);
      }
    });
  });
}
