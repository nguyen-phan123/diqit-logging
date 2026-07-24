import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('DiqitLogPrinter & DShorthandPrinter Tracing', () {
    test('traceId should appear once in log line when in TraceZone', () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      const traceId = 'createOrder_1784867983330';

      DiqitLogger.runInTraceZone(() {
        DiqitLogger.i('masterCreateOrder', tag: LogTag.order);
      }, traceId: traceId);

      final history = DiqitLogger.getLogHistory();
      expect(history, isNotEmpty);
      final lastLogLines = history.last.lines;
      final fullLog = lastLogLines.join('\n');

      final occurrences = traceId.allMatches(fullLog).length;
      expect(
        occurrences,
        equals(1),
        reason:
            'traceId $traceId appeared $occurrences times in log: "$fullLog"',
      );
    });

    test('traceId should appear once in full method when in TraceZone',
        () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      const traceId = 'createOrder_1784867983330';

      DiqitLogger.runInTraceZone(() {
        DiqitLogger.info('masterCreateOrder', tag: LogTag.order);
      }, traceId: traceId);

      final history = DiqitLogger.getLogHistory();
      expect(history, isNotEmpty);
      final lastLogLines = history.last.lines;
      final fullLog = lastLogLines.join('\n');

      final occurrences = traceId.allMatches(fullLog).length;
      expect(
        occurrences,
        equals(1),
        reason:
            'traceId $traceId appeared $occurrences times in log: "$fullLog"',
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
