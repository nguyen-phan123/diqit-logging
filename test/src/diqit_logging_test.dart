// ignore_for_file: prefer_const_constructors
import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('DiqitLogging', () {
    test('can be instantiated', () {
      expect(DiqitLogger(), isNotNull);
    });

    test('instance constructor creates logger with path', () {
      final logger = DiqitLogger('kds');
      expect(logger, isNotNull);
    });

    test('shorthand and full methods both produce output', () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      DiqitLogger.i('shorthand log');
      final shorthandLines = DiqitLogger.getLogHistory().last.lines;

      DiqitLogger.info('full log', countMethod: 2);
      final fullLines = DiqitLogger.getLogHistory().last.lines;

      expect(shorthandLines.first, contains('shorthand log'));
      expect(fullLines.first, contains('full log'));
    });
  });
}
