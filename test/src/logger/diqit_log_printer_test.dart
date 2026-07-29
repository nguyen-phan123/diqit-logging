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

    test('emoji comes before timestamp with ms in DShorthandPrinter', () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      DiqitLogger.i('test timestamp with ms');

      final history = DiqitLogger.getLogHistory();
      expect(history, isNotEmpty);
      final lastLogLines = history.last.lines;
      final firstLine = lastLogLines.first;

      // Expect emoji followed by [HH:mm:ss.SSS] e.g. "ℹ [13:32:31.091]"
      final regex = RegExp(r'ℹ.*\[\d{2}:\d{2}:\d{2}\.\d{3}\]');
      expect(
        regex.hasMatch(firstLine),
        isTrue,
        reason: 'Emoji should come before timestamp: "$firstLine"',
      );
    });
  });
}
