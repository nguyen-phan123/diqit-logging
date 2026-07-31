import 'package:diqit_logging/src/logger/message/diqit_log_message.dart';
import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:test/test.dart';

void main() {
  group('DLogMessage formatting', () {
    test('data payload starts on a new line after message', () {
      final msg = DLogMessage(
        message: 'map_bundle_batch',
        tag: LogTag.custom('kds/make_bloc'),
        data: [
          {'uuid': 'abc-123', 'orderUuid': 'abc-123', 'index': 100.0},
        ],
      );

      final output = msg.toString();

      // The data JSON must start on a NEW line, not the same line as message
      expect(output, isNot(contains('map_bundle_batch {')));
      expect(output, isNot(contains('map_bundle_batch "data"')));
      expect(output, isNot(contains('map_bundle_batch \n"')));
    });

    test('data payload newline placement is correct', () {
      final msg = DLogMessage(
        message: 'order_created',
        tag: LogTag.custom('ot/bloc'),
        data: {'order_id': 'ORD-001', 'total': 45000},
      );

      final output = msg.toString();

      // message and data payload MUST be on separate lines
      final lines = output.split('\n');
      expect(lines[0].trim(), contains('order_created'));
      // After the message line, the data should follow
      // Not asserting exact format — just that they're separated
      expect(lines.length, greaterThan(1),
          reason: 'Data payload should appear on lines after the message');
    });
  });
}
