// ignore_for_file: deprecated_member_use_from_same_package
import 'package:diqit_logging/diqit_logging.dart';
import 'package:test/test.dart';

void main() {
  group('DiqitLogger.updateConfig', () {
    test('should update tag filters without re-initializing', () async {
      // Initialize with all tags enabled
      var config = LoggerConfig.development();
      await DiqitLogger.initialize(config);

      // Verify UI tag is enabled
      expect(config.isTagEnabled(LogTag.ui), true);
      DiqitLogger.i('UI log before disable', tag: LogTag.ui);
      DiqitLogger.i('NETWORK log before disable', tag: LogTag.network);

      var history = DiqitLogger.getLogHistory();
      expect(history.length, 2);

      // Update config to disable UI tag
      final newConfig = config.withTagsDisabled(['UI', 'BLOC']);
      await DiqitLogger.updateConfig(newConfig);

      // Verify UI tag is now disabled
      expect(newConfig.isTagEnabled(LogTag.ui), false);
      expect(newConfig.isTagEnabled(LogTag.network), true);

      // Try logging with disabled tag - should NOT appear
      DiqitLogger.i('UI log after disable - SHOULD NOT APPEAR', tag: LogTag.ui);
      DiqitLogger.i('NETWORK log after disable - SHOULD APPEAR',
          tag: LogTag.network);

      history = DiqitLogger.getLogHistory();

      // Should have 3 logs total (2 before + 1 NETWORK after)
      // UI log after disable should be filtered out
      expect(history.length, 3);

      // Verify the last log is NETWORK, not UI
      final lastLog = history.last.lines.join();
      expect(lastLog.contains('NETWORK'), true);
      expect(lastLog.contains('SHOULD APPEAR'), true);
    });

    test('should update console logging setting', () async {
      var config = LoggerConfig.development();
      await DiqitLogger.initialize(config);

      // Update to disable console logging
      final newConfig = config.copyWith(enableConsoleLogging: false);
      await DiqitLogger.updateConfig(newConfig);

      // Logs should still be captured in history but not printed to console
      DiqitLogger.i('Test message');
      final history = DiqitLogger.getLogHistory();
      expect(history.isNotEmpty, true);
    });

    test('should update prefix message', () async {
      var config = LoggerConfig.development(prefixMessage: '[APP1] ');
      await DiqitLogger.initialize(config);

      final historyBefore = DiqitLogger.getLogHistory().length;

      DiqitLogger.i('Message with APP1 prefix');

      // Update prefix
      final newConfig = config.copyWith(prefixMessage: '[APP2] ');
      await DiqitLogger.updateConfig(newConfig);

      DiqitLogger.i('Message with APP2 prefix');

      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter - historyBefore, 2);
    });

    test('should work even if not initialized yet', () async {
      // Call updateConfig before initialize
      final config = LoggerConfig.development();
      await DiqitLogger.updateConfig(config);

      // Should work without errors
      DiqitLogger.i('Test message');
      final history = DiqitLogger.getLogHistory();
      expect(history.isNotEmpty, true);
    });

    test('should update multiple times in succession', () async {
      var config = LoggerConfig.development();
      await DiqitLogger.initialize(config);

      final historyBefore = DiqitLogger.getLogHistory().length;

      // First update: disable UI
      config = config.withTagsDisabled(['UI']);
      await DiqitLogger.updateConfig(config);
      DiqitLogger.i('Should not appear', tag: LogTag.ui);
      DiqitLogger.i('Should appear 1', tag: LogTag.network);

      // Second update: disable NETWORK too
      config = config.withTagsDisabled(['NETWORK']);
      await DiqitLogger.updateConfig(config);
      DiqitLogger.i('Should not appear', tag: LogTag.network);
      DiqitLogger.i('Should appear 2', tag: LogTag.database);

      // Third update: re-enable UI
      config = config.withTagsEnabled(['UI']);
      await DiqitLogger.updateConfig(config);
      DiqitLogger.i('Should appear 3', tag: LogTag.ui);

      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter - historyBefore,
          3); // Only 3 logs should pass the filters
    });
  });
}
