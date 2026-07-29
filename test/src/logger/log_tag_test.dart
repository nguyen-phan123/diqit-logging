import 'package:diqit_logging/src/logger/log_tag.dart';
import 'package:test/test.dart';

void main() {
  group('LogTag', () {
    test('values includes all predefined static LogTag constants', () {
      expect(LogTag.values, contains(LogTag.none));
      expect(LogTag.values, contains(LogTag.ui));
      expect(LogTag.values, contains(LogTag.bloc));
      expect(LogTag.values, contains(LogTag.state));
      expect(LogTag.values, contains(LogTag.usecase));
      expect(LogTag.values, contains(LogTag.repository));
      expect(LogTag.values, contains(LogTag.network));
      expect(LogTag.values, contains(LogTag.database));
      expect(LogTag.values, contains(LogTag.mqtt));
      expect(LogTag.values, contains(LogTag.navigation));
      expect(LogTag.values, contains(LogTag.event));
      expect(LogTag.values, contains(LogTag.sync));
      expect(LogTag.values, contains(LogTag.order));
      expect(LogTag.values, contains(LogTag.payment));
      expect(LogTag.values, contains(LogTag.printer));
      expect(LogTag.values, contains(LogTag.kds));
    });

    test('kds tag has label KDS', () {
      expect(LogTag.kds.label, equals('KDS'));
      expect(LogTag.kds.toString(), equals('KDS'));
    });

    test('custom tag creates LogTag with custom label', () {
      final tag = LogTag.custom('CUSTOM');
      expect(tag.label, equals('CUSTOM'));
      expect(tag, equals(const LogTag('CUSTOM')));
    });

    test('equality and hashCode work correctly', () {
      final tag1 = LogTag.custom('KDS');
      final tag2 = LogTag.custom('KDS');
      final tag3 = LogTag.custom('UI');

      expect(tag1, equals(tag2));
      expect(tag1.hashCode, equals(tag2.hashCode));
      expect(tag1, isNot(equals(tag3)));
    });
  });
}
