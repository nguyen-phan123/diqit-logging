import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

class CustomUser {
  final String id;
  final String name;

  CustomUser({required this.id, required this.name});
}

void main() {
  group('Scoped Logger Root Delegation', () {
    setUp(() async {
      await DiqitLogger.initialize(
        LoggerConfig.development(minLogLevel: Level.trace),
      );
      DiqitLogger.clearLogHistory();
    });

    test('constructor and static scoped factory create loggers with path', () {
      final logger1 = DiqitLogger('kds');
      final logger2 = DiqitLogger.scoped('payment');

      logger1.i('KDS event');
      final lines1 = DiqitLogger.getLogHistory().last.lines;
      expect(lines1.first, contains('[kds]'));
      expect(lines1.first, contains('KDS event'));

      logger2.i('Payment event');
      final lines2 = DiqitLogger.getLogHistory().last.lines;
      expect(lines2.first, contains('[payment]'));
      expect(lines2.first, contains('Payment event'));
    });

    test('nested createChild builds slash-delimited path hierarchy', () {
      final parent = DiqitLogger('kds');
      final child = parent.createChild('order_grid');

      child.i('Nested order event');
      final lines = DiqitLogger.getLogHistory().last.lines;
      expect(lines.first, contains('[kds/order_grid]'));
      expect(lines.first, contains('Nested order event'));
    });

    test('scoped logger dynamically delegates updateConfig to root', () async {
      final scopedLogger = DiqitLogger.scoped('sync');

      // Trace logs should appear under debug config
      scopedLogger.t('Initial trace log');
      expect(
        DiqitLogger.getLogHistory()
            .any((e) => e.lines.first.contains('Initial trace log')),
        isTrue,
      );

      // Dynamically update config via static API to suppress trace logs
      await DiqitLogger.updateConfig(
        LoggerConfig.development(minLogLevel: Level.info),
      );

      DiqitLogger.clearLogHistory();
      scopedLogger.t('Suppressed trace log');
      expect(DiqitLogger.getLogHistory(), isEmpty);

      // Info log should still pass
      scopedLogger.i('Active info log');
      expect(
        DiqitLogger.getLogHistory()
            .any((e) => e.lines.first.contains('Active info log')),
        isTrue,
      );
    });

    test('scoped logger dynamically delegates type converters on root', () {
      final scopedLogger = DiqitLogger('user_module');
      final user = CustomUser(id: 'usr-1', name: 'Alice');

      // Register converter on root via static API
      DiqitLogger.registerConverter<CustomUser>(
        (u) => 'User(id: ${u.id}, name: ${u.name})',
      );

      scopedLogger.i('User profile updated', data: user);
      final event = DiqitLogger.getLogHistory().last;
      final fullOutput = event.lines.join('\n');

      expect(fullOutput, contains('[user_module]'));
      expect(fullOutput, contains('User profile updated'));
      expect(fullOutput, contains('User(id: usr-1, name: Alice)'));
    });
  });
}
