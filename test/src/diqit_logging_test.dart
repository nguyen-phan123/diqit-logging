// ignore_for_file: prefer_const_constructors, deprecated_member_use_from_same_package
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

    group('Static Shortcuts (Canonical API)', () {
      setUp(() async {
        await DiqitLogger.initialize(
          LoggerConfig.development(minLogLevel: Level.trace),
        );
      });

      test('t() logs trace level', () {
        DiqitLogger.t('trace message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('trace message'));
      });

      test('d() logs debug level', () {
        DiqitLogger.d('debug message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('debug message'));
      });

      test('i() logs info level', () {
        DiqitLogger.i('info message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('info message'));
      });

      test('w() logs warning level', () {
        DiqitLogger.w('warning message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('warning message'));
      });

      test('e() logs error level', () {
        DiqitLogger.e('error message', error: Exception('test'));
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('error message'));
      });

      test('ft() logs fatal level', () {
        DiqitLogger.ft('fatal message', error: Exception('test'));
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('fatal message'));
      });
    });

    group('Instance Shortcuts (Extension)', () {
      setUp(() async {
        await DiqitLogger.initialize(
          LoggerConfig.development(minLogLevel: Level.trace),
        );
      });

      test('instance.t() logs trace level', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.t('trace message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('trace message'));
        expect(lines.any((l) => l.contains('[kds]')), true);
      });

      test('instance.d() logs debug level', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.d('debug message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('debug message'));
      });

      test('instance.i() logs info level', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.i('info message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('info message'));
      });

      test('instance.w() logs warning level', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.w('warning message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('warning message'));
      });

      test('instance.e() logs error level', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.e('error message', error: Exception('test'));
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('error message'));
      });

      test('instance.ft() logs fatal level', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.ft('fatal message', error: Exception('test'));
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('fatal message'));
      });
    });

    group('Deprecation Warnings', () {
      test('full methods are deprecated', () {
        expect(DiqitLogger.trace, isNotNull);
        expect(DiqitLogger.debug, isNotNull);
        expect(DiqitLogger.info, isNotNull);
        expect(DiqitLogger.warning, isNotNull);
        expect(DiqitLogger.error, isNotNull);
        expect(DiqitLogger.fatal, isNotNull);
      });
    });

    group('Instance Shortcuts with Parameters', () {
      setUp(() async {
        await DiqitLogger.initialize(LoggerConfig.development());
      });

      test('instance.i() with data parameter', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.i('message with data', data: {'key': 'value'});
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('message with data'));
      });

      test('instance.i() with tag parameter', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.i('message with tag', tag: LogTag.custom('order'));
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('message with tag'));
      });

      test('instance.i() with context parameter', () {
        final logger = DiqitLogger.root.createChild('kds');
        logger.i('message with context', context: {'userId': 123});
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('message with context'));
      });

      test('nested child logger preserves hierarchy', () {
        final parent = DiqitLogger.root.createChild('kds');
        final child = parent.createChild('order_grid');
        child.i('nested message');
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('nested message'));
      });

      test('instance.e() with error and stacktrace', () {
        final logger = DiqitLogger.root.createChild('kds');
        final error = Exception('test error');
        final stack = StackTrace.current;
        logger.e('error with stack', error: error, stackTrace: stack);
        final lines = DiqitLogger.getLogHistory().last.lines;
        expect(lines.first, contains('error with stack'));
      });
    });
  });
}
