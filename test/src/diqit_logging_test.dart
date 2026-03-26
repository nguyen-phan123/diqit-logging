// ignore_for_file: prefer_const_constructors
import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('DiqitLogging', () {
    test('can be instantiated', () {
      expect(DiqitLogger(), isNotNull);
    });

    test('detailed loggers should respect countMethod parameter', () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      DiqitLogger.info('Message default');
      final linesDefault = DiqitLogger.getLogHistory().last.lines.length;

      DiqitLogger.info('Message countMethod 2', countMethod: 2);
      final linesWith2 = DiqitLogger.getLogHistory().last.lines.length;

      DiqitLogger.info('Message countMethod 5', countMethod: 5);
      final linesWith5 = DiqitLogger.getLogHistory().last.lines.length;

      // The count of lines should scale with countMethod stack frames
      expect(linesWith5 > linesWith2, true);
      // Depending on default trace behavior, linesDefault might be 8 frames
      expect(linesDefault > linesWith2, true);
    });
  });
}
