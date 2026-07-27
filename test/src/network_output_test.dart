// ignore_for_file: prefer_const_constructors
import 'dart:io';

import 'package:diqit_logging/diqit_logging.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

LogEvent _makeEvent(Level level, String msg) => LogEvent(level, msg);

void main() {
  group('NetworkOutput', () {
    late NetworkOutput output;

    tearDown(() async {
      await output.stop();
    });

    test('starts listening and reports actualPort', () async {
      output = NetworkOutput(port: 0);
      await output.start();

      expect(output.isRunning, isTrue);
      expect(output.actualPort, isNot(0));
    });

    test('can send output events to connected WebSocket client', () async {
      output = NetworkOutput(port: 0);
      await output.start();

      final ws = await WebSocket.connect(
        'ws://127.0.0.1:${output.actualPort}',
      );

      final event = OutputEvent(
        _makeEvent(Level.info, 'test message'),
        ['test line 1', 'test line 2'],
      );
      output.output(event);

      final received = <String>[];
      await for (final message in ws) {
        received.add(message as String);
        if (received.length >= 2) break;
      }

      await ws.close();

      expect(received.first, contains('test line 1'));
    });

    test('sends buffer events to newly connected client', () async {
      output = NetworkOutput(port: 0);

      final buffer = [
        OutputEvent(_makeEvent(Level.info, 'm1'), ['buffered line 1']),
        OutputEvent(_makeEvent(Level.debug, 'm2'), ['buffered line 2']),
      ];

      await output.start(bufferGetter: () => buffer);

      final ws = await WebSocket.connect(
        'ws://127.0.0.1:${output.actualPort}',
      );

      final received = <String>[];
      await for (final message in ws) {
        received.add(message as String);
        if (received.length >= buffer.length) break;
      }

      await ws.close();

      expect(received.first, contains('buffered line 1'));
      expect(received.last, contains('buffered line 2'));
    });

    test('stop shuts down the server', () async {
      output = NetworkOutput(port: 0);
      await output.start();
      final port = output.actualPort;

      await output.stop();

      expect(output.isRunning, isFalse);
      await expectLater(
        () => WebSocket.connect('ws://127.0.0.1:$port'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('LoggerConfig', () {
    test('enableNetworkLogging defaults to false', () {
      final config = LoggerConfig();
      expect(config.enableNetworkLogging, isFalse);
    });

    test('networkPort defaults to 9229', () {
      final config = LoggerConfig();
      expect(config.networkPort, equals(9229));
    });

    test('copyWith preserves network fields', () {
      final original = LoggerConfig(
        enableNetworkLogging: true,
        networkPort: 8080,
      );

      final copied = original.copyWith();

      expect(copied.enableNetworkLogging, isTrue);
      expect(copied.networkPort, equals(8080));
    });

    test('copyWith can update network fields', () {
      final config = LoggerConfig();

      final updated = config.copyWith(
        enableNetworkLogging: true,
        networkPort: 5432,
      );

      expect(updated.enableNetworkLogging, isTrue);
      expect(updated.networkPort, equals(5432));
    });
  });

  group('DiqitLogger + NetworkOutput', () {
    tearDown(() async {
      await DiqitLogger.root.networkOutput?.stop();
    });

    test('does not start network server when enableNetworkLogging is false',
        () async {
      await DiqitLogger.initialize(LoggerConfig.development());

      expect(DiqitLogger.root.networkOutput, isNull);
    });

    test('streams log messages to WebSocket client', () async {
      await DiqitLogger.initialize(
        LoggerConfig.development().copyWith(
          enableNetworkLogging: true,
          networkPort: 0,
        ),
      );

      final port = DiqitLogger.root.networkOutput!.actualPort;
      final ws = await WebSocket.connect('ws://127.0.0.1:$port');

      DiqitLogger.i('hello from websocket test');

      String? received;
      await for (final message in ws) {
        received = message as String;
        break;
      }

      await ws.close();

      expect(received, isNotNull);
      expect(received!, contains('hello from websocket test'));
    });

    test('sends buffer history to new client on connect', () async {
      await DiqitLogger.initialize(
        LoggerConfig.development().copyWith(
          enableNetworkLogging: true,
          networkPort: 0,
        ),
      );

      DiqitLogger.i('first buffered message');
      DiqitLogger.i('second buffered message');

      final port = DiqitLogger.root.networkOutput!.actualPort;
      final ws = await WebSocket.connect('ws://127.0.0.1:$port');

      final received = <String>[];
      await for (final message in ws) {
        final s = message as String;
        if (s.contains('buffered')) {
          received.add(s);
          if (received.length >= 2) break;
        }
      }

      await ws.close();

      expect(received.length, equals(2));
      expect(received.first, contains('first buffered message'));
      expect(received.last, contains('second buffered message'));
    });

    test('clearLogHistory() empties the log buffer', () async {
      await DiqitLogger.initialize(
        LoggerConfig.development().copyWith(
          enableNetworkLogging: true,
          networkPort: 0,
        ),
      );

      DiqitLogger.i('message before clear');

      final before = DiqitLogger.getLogHistory();
      expect(before, isNotEmpty);

      DiqitLogger.clearLogHistory();

      final after = DiqitLogger.getLogHistory();
      expect(after, isEmpty);
    });

    test('!clear command via WebSocket clears buffer and sends OK',
        () async {
      await DiqitLogger.initialize(
        LoggerConfig.development().copyWith(
          enableNetworkLogging: true,
          networkPort: 0,
        ),
      );

      DiqitLogger.i('message to be cleared');

      final port = DiqitLogger.root.networkOutput!.actualPort;
      final ws = await WebSocket.connect('ws://127.0.0.1:$port');

      ws.add('!clear');

      String? response;
      await for (final message in ws) {
        final s = message as String;
        if (s.contains('!OK')) {
          response = s;
          break;
        }
      }

      await ws.close();

      expect(response, equals('!OK Buffer cleared'));
      expect(DiqitLogger.getLogHistory(), isEmpty);
    });

    test('!copy command via WebSocket sends formatted buffer dump',
        () async {
      await DiqitLogger.initialize(
        LoggerConfig.development().copyWith(
          enableNetworkLogging: true,
          networkPort: 0,
        ),
      );

      DiqitLogger.clearLogHistory();

      DiqitLogger.i('copy target message');

      final port = DiqitLogger.root.networkOutput!.actualPort;
      final ws = await WebSocket.connect('ws://127.0.0.1:$port');

      ws.add('!copy');

      final received = <String>[];
      var collecting = false;
      await for (final message in ws) {
        final s = message as String;
        if (s.contains('--- BEGIN LOG COPY ---')) {
          collecting = true;
        }
        if (collecting) {
          received.add(s);
        }
        if (s.contains('--- END LOG COPY ---')) break;
      }

      await ws.close();

      expect(
        received.first,
        contains('--- BEGIN LOG COPY ---'),
      );
      expect(received.any((s) => s.contains('copy target message')), isTrue);
      expect(received.last, contains('--- END LOG COPY ---'));
    });

    test('!help command via WebSocket shows available commands', () async {
      await DiqitLogger.initialize(
        LoggerConfig.development().copyWith(
          enableNetworkLogging: true,
          networkPort: 0,
        ),
      );

      final port = DiqitLogger.root.networkOutput!.actualPort;
      final ws = await WebSocket.connect('ws://127.0.0.1:$port');

      ws.add('!help');

      final received = <String>[];
      await for (final message in ws) {
        final s = message as String;
        if (s.startsWith('!')) {
          received.add(s);
          if (received.length >= 3) break;
        }
      }

      await ws.close();

      expect(received.length, equals(3));
      expect(received[0], contains('!clear'));
      expect(received[1], contains('!copy'));
      expect(received[2], contains('!help'));
    });
  });
}
