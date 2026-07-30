// ignore_for_file: prefer_const_constructors, deprecated_member_use_from_same_package
import 'package:diqit_logging/diqit_logging.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  group('DiqitLogger.flow() - T1: Basic Behavior', () {
    setUp(() async {
      await DiqitLogger.initialize(LoggerConfig.development());
    });

    test('logs at Level.debug', () {
      // Act
      DiqitLogger.flow();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      expect(lastLog.level, equals(Level.debug));
    });

    test('uses LogTag.custom("function")', () {
      // Act
      DiqitLogger.flow();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should contain 'function' tag in the output
      expect(logOutput, contains('function'));
    });

    test('formats output as [Caller -> CurrentFunction]', () {
      // Arrange: create caller -> current function chain
      void currentFunction() {
        DiqitLogger.flow();
      }

      void callerFunction() {
        currentFunction();
      }

      // Act
      callerFunction();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should contain '->' indicating caller -> current format
      // Note: local functions show as 'main.<anonymous' in stack traces
      expect(logOutput, contains('->'));
      expect(logOutput, contains('['));
      expect(logOutput, contains(']'));
    });

    test('formats output as [CurrentFunction] when no caller detected', () {
      // Act - call flow at top level (no clear caller)
      DiqitLogger.flow();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should contain some function name in brackets
      expect(logOutput, contains('['));
      expect(logOutput, contains(']'));
    });
  });

  group('DiqitLogger.flow() - T2: Parameter Logging', () {
    setUp(() async {
      await DiqitLogger.initialize(LoggerConfig.development());
    });

    test('includes Params: when args provided', () {
      // Act
      DiqitLogger.flow(args: {'user_id': 123, 'action': 'login'});

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('Params:'));
      expect(logOutput, contains('user_id'));
      expect(logOutput, contains('123'));
      expect(logOutput, contains('action'));
      expect(logOutput, contains('login'));
    });

    test('does NOT include Params: line when no args', () {
      // Act
      DiqitLogger.flow();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, isNot(contains('Params:')));
    });

    test('handles empty args map', () {
      // Act
      DiqitLogger.flow(args: {});

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Empty map should not trigger Params: line
      expect(logOutput, isNot(contains('Params:')));
    });

    test('handles multiple parameters with various data types', () {
      // Act
      DiqitLogger.flow(args: {
        'string_key': 'value',
        'int_key': 42,
        'bool_key': true,
        'double_key': 3.14,
      });

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      expect(logOutput, contains('Params:'));
      expect(logOutput, contains('string_key'));
      expect(logOutput, contains('int_key'));
      expect(logOutput, contains('bool_key'));
      expect(logOutput, contains('double_key'));
    });
  });

  group('DiqitLogger.flow() - T3: Tag Filtering', () {
    test('flow logs are hidden when function tag is disabled', () async {
      // Arrange: disable 'function' tag
      final config = LoggerConfig.development().withTagsDisabled(['function']);
      await DiqitLogger.initialize(config);

      final historyBefore = DiqitLogger.getLogHistory().length;

      // Act
      DiqitLogger.flow(); // Should be filtered out

      // Assert
      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter, equals(historyBefore)); // No new log
    });

    test('flow logs appear when function tag is enabled', () async {
      // Arrange: explicitly enable 'function' tag
      final config = LoggerConfig.development().withTagsEnabled(['function']);
      await DiqitLogger.initialize(config);

      final historyBefore = DiqitLogger.getLogHistory().length;

      // Act
      DiqitLogger.flow();

      // Assert
      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter, equals(historyBefore + 1)); // New log added
    });

    test(
        'flow logs are filtered out with searchTagPatterns set to different tag',
        () async {
      // Arrange: only 'network' tag in search patterns
      final config = LoggerConfig.development(
        searchTagPatterns: ['network'],
      );
      await DiqitLogger.initialize(config);

      final historyBefore = DiqitLogger.getLogHistory().length;

      // Act
      DiqitLogger.flow(); // Should be filtered out
      DiqitLogger.d('network call', tag: LogTag.network); // Should appear

      // Assert
      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter, equals(historyBefore + 1)); // Only network log

      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');
      expect(logOutput, contains('network call'));
    });

    test('flow logs appear when searchTagPatterns includes function', () async {
      // Arrange: 'function' in search patterns
      final config = LoggerConfig.development(
        searchTagPatterns: ['function'],
      );
      await DiqitLogger.initialize(config);

      final historyBefore = DiqitLogger.getLogHistory().length;

      // Act
      DiqitLogger.flow();

      // Assert
      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter, equals(historyBefore + 1));
    });

    test('respects allowCustomTags setting', () async {
      // Arrange: disable custom tags
      final config = LoggerConfig(
        enableConsoleLogging: true,
        allowCustomTags: false,
        minLogLevel: Level.debug,
      );
      await DiqitLogger.initialize(config);

      final historyBefore = DiqitLogger.getLogHistory().length;

      // Act
      DiqitLogger.flow(); // Custom 'function' tag should be filtered

      // Assert
      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter, equals(historyBefore)); // No new log
    });

    test('can change filtering at runtime via updateConfig', () async {
      // Arrange: start with function tag disabled
      final config1 = LoggerConfig.development().withTagsDisabled(['function']);
      await DiqitLogger.initialize(config1);

      final historyBefore = DiqitLogger.getLogHistory().length;
      DiqitLogger.flow(); // Should be filtered
      expect(DiqitLogger.getLogHistory().length, equals(historyBefore));

      // Act: enable function tag at runtime
      final config2 = config1.withTagsEnabled(['function']);
      await DiqitLogger.updateConfig(config2);

      DiqitLogger.flow(); // Should now appear

      // Assert
      final historyAfter = DiqitLogger.getLogHistory().length;
      expect(historyAfter, equals(historyBefore + 1));
    });
  });

  group('DiqitLogger.flow() - T4: Edge Cases', () {
    setUp(() async {
      await DiqitLogger.initialize(LoggerConfig.development());
    });

    test('strips anonymous closure artifacts from function names', () {
      // Arrange: create an anonymous closure
      void outerFunction() {
        final closure = () {
          DiqitLogger.flow();
        };
        closure();
      }

      // Act
      outerFunction();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should not contain '<anonymous closure>' in output
      expect(logOutput, isNot(contains('<anonymous closure>')));
    });

    test('handles async function contexts', () async {
      // Arrange: async function
      Future<void> asyncFunction() async {
        DiqitLogger.flow();
      }

      // Act
      await asyncFunction();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should produce some output (even if caller is async machinery)
      expect(logOutput, isNotEmpty);
      expect(logOutput, contains('['));
      expect(logOutput, contains(']'));
    });

    test('handles nested function calls', () {
      // Arrange: deep call stack
      void level3Func() {
        DiqitLogger.flow();
      }

      void level2Func() {
        level3Func();
      }

      void level1Func() {
        level2Func();
      }

      // Act
      level1Func();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should show caller -> current format (immediate caller -> current)
      // Note: local functions show as 'main.<anonymous' in stack traces
      expect(logOutput, contains('->'));
      expect(logOutput, contains('['));
      expect(logOutput, contains(']'));
    });

    test('produces valid output even with complex stack traces', () async {
      // Arrange: mix of sync and callback contexts
      void outerSync() {
        DiqitLogger.flow();
      }

      // Act
      outerSync();

      // Assert
      final lastLog = DiqitLogger.getLogHistory().last;
      final logOutput = lastLog.lines.join('\n');

      // Should produce some output (defensive behavior)
      expect(logOutput, isNotEmpty);
      expect(logOutput, contains('['));
    });
  });
}
