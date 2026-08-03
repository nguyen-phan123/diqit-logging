import 'package:diqit_logging/src/logger/log_element.dart';
import 'package:diqit_logging/src/logger/message/diqit_log_message.dart';
import 'package:diqit_logging/src/logger/printter/row_printer.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  group('LogFunctionElement', () {
    test('renders explicit member from DLogMessage', () {
      const element = LogFunctionElement();
      final ctx = LogRenderContext(
        message: const DLogMessage(
          message: 'test msg',
          member: 'OrderHistoryPage._printReceipt',
        ),
        level: Level.info,
        timestamp: DateTime.now(),
        sequenceNum: 1,
        isColorEnabled: false,
      );

      final result = element.build(ctx);
      expect(result, equals('{OrderHistoryPage._printReceipt}'));
    });

    test('renders member when already wrapped in curly braces', () {
      const element = LogFunctionElement();
      final ctx = LogRenderContext(
        message: const DLogMessage(
          message: 'test msg',
          member: '{CustomClass.customMethod}',
        ),
        level: Level.info,
        timestamp: DateTime.now(),
        sequenceNum: 1,
        isColorEnabled: false,
      );

      final result = element.build(ctx);
      expect(result, equals('{CustomClass.customMethod}'));
    });

    test('renders fallbackMember when message has no member or stacktrace', () {
      const element = LogFunctionElement(fallbackMember: 'DefaultModule.run');
      final ctx = LogRenderContext(
        message: const DLogMessage(message: 'test msg'),
        level: Level.info,
        timestamp: DateTime.now(),
        sequenceNum: 1,
        isColorEnabled: false,
      );

      final result = element.build(ctx);
      expect(result, equals('{DefaultModule.run}'));
    });

    test('parses member from stackTrace when message.member is null', () {
      const element = LogFunctionElement();
      final fakeStackTrace = StackTrace.fromString('''
#0      DiqitLogger.d (package:diqit_logging/src/diqit_logging.dart:10:5)
#1      OrderService.createOrder (package:ot/domain/order_service.dart:42:12)
#2      _InkResponseState.handleTap (package:flutter/src/material/ink_well.dart:1179:21)
''');

      final ctx = LogRenderContext(
        message: const DLogMessage(message: 'test msg'),
        level: Level.info,
        timestamp: DateTime.now(),
        sequenceNum: 1,
        isColorEnabled: false,
        stackTrace: fakeStackTrace,
      );

      final result = element.build(ctx);
      expect(result, equals('{OrderService.createOrder}'));
    });

    test('applies ANSI color when isColorEnabled is true', () {
      const element = LogFunctionElement();
      final ctx = LogRenderContext(
        message: const DLogMessage(
          message: 'test msg',
          member: 'MyClass.myMethod',
        ),
        level: Level.error,
        timestamp: DateTime.now(),
        sequenceNum: 1,
        isColorEnabled: true,
      );

      final result = element.build(ctx);
      expect(result, contains(LogAnsiColor.forLevel(Level.error)));
      expect(result, contains('{MyClass.myMethod}'));
      expect(result, contains(LogAnsiColor.reset));
    });
  });

  group('RowPrinter integration with LogFunctionElement', () {
    test('default RowPrinter contains LogFunctionElement in header', () {
      final printer = RowPrinter(enableColors: false);
      const msg = DLogMessage(
        message: 'Order created successfully',
        path: 'ot/order',
        member: 'OrderGridBloc.onFetchOrders',
      );
      final event = LogEvent(Level.info, msg);
      final lines = printer.log(event);

      expect(lines.first, contains('{OrderGridBloc.onFetchOrders}'));
      expect(lines.first, contains('[ot/order]'));
    });
  });
}
