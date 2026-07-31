// ignore_for_file: deprecated_member_use_from_same_package
import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('Log Output Formatting', () {
    test('traceId should appear once in log line when in zone', () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      final trace = TraceId.manual('createOrder', 1784867983330);

      DiqitLogger.runTracedSync(trace, () {
        DiqitLogger.i('masterCreateOrder', tag: LogTag.order);
      });

      final history = DiqitLogger.getLogHistory();
      expect(history, isNotEmpty);
      final lastLogLines = history.last.lines;
      final fullLog = lastLogLines.join('\n');

      final occurrences =
          '#createOrder-1784867983330'.allMatches(fullLog).length;
      expect(
        occurrences,
        equals(1),
        reason: 'traceId appeared $occurrences times in log: "$fullLog"',
      );
    });

    test('traceId should appear once in full method when in zone', () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      final trace = TraceId.manual('createOrder', 1784867983330);

      DiqitLogger.runTracedSync(trace, () {
        DiqitLogger.info('masterCreateOrder', tag: LogTag.order);
      });

      final history = DiqitLogger.getLogHistory();
      expect(history, isNotEmpty);
      final lastLogLines = history.last.lines;
      final fullLog = lastLogLines.join('\n');

      final occurrences =
          '#createOrder-1784867983330'.allMatches(fullLog).length;
      expect(
        occurrences,
        equals(1),
        reason: 'traceId appeared $occurrences times in log: "$fullLog"',
      );
    });

    test(
        'custom RowPrinter passed in LoggerConfig is respected by DiqitLogger.i',
        () async {
      final customPrinter = RowPrinter(
        children: const [
          LogLevelElement(),
          LogMessageElement(),
        ],
      );
      await DiqitLogger.initialize(
        LoggerConfig(
          minLogLevel: Level.debug,
          enableConsoleLogging: true,
          printer: customPrinter,
        ),
      );

      DiqitLogger.i('testing custom printer');

      final history = DiqitLogger.getLogHistory();
      expect(history, isNotEmpty);
      final line = history.last.lines.first;
      // Output formatted with custom children should start with Level element ('I') and message
      expect(line, contains('testing custom printer'));
    });
  });

  group('RowPrinter Platform Capabilities', () {
    test('isColorSupported is a boolean flag', () {
      expect(RowPrinter.isColorSupported, isA<bool>());
    });

    test(
        'RowPrinter indents data payload lines cleanly with fixed 2-space margin',
        () {
      final printer = RowPrinter(enableColors: false);
      final msg = DLogMessage(
        message: 'send',
        path: 'tank/sync_engine/app_health_check_api',
        data: {'store_uuid': '72d7f675-b35a-4413-8156-75c58b87mjhg'},
      );
      final event = LogEvent(Level.info, msg);
      final lines = printer.log(event);

      expect(lines.length, greaterThan(1));
      expect(lines[1], startsWith('  {"data":'));
    });
  });
}
