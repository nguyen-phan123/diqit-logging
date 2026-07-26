import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';

class NetworkOutput extends LogOutput {
  final int port;
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  List<OutputEvent> Function()? _bufferGetter;

  NetworkOutput({this.port = 9229});

  int get actualPort => _server?.port ?? 0;

  bool get isRunning => _server != null;

  Future<void> start({List<OutputEvent> Function()? bufferGetter}) async {
    _bufferGetter = bufferGetter;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    _server!.listen(
      (HttpRequest req) {
        if (!WebSocketTransformer.isUpgradeRequest(req)) {
          req.response.statusCode = HttpStatus.notFound;
          req.response.close();
          return;
        }

        WebSocketTransformer.upgrade(req).then(_handleClient);
      },
      onError: (Object error) {
        stderr.writeln('NetworkOutput error: $error');
      },
    );
  }

  void _handleClient(WebSocket ws) {
    _clients.add(ws);

    final buffer = _bufferGetter?.call();
    if (buffer != null) {
      for (final event in buffer) {
        for (final line in event.lines) {
          _sendLine(ws, line);
        }
      }
    }

    ws.done.then((_) => _clients.remove(ws));
  }

  void _sendLine(WebSocket ws, String line) {
    try {
      ws.add(line.replaceAll('\n', ' '));
    } catch (_) {
      _clients.remove(ws);
    }
  }

  @override
  void output(OutputEvent event) {
    final deadClients = <WebSocket>[];
    for (final client in _clients) {
      try {
        for (final line in event.lines) {
          client.add(line.replaceAll('\n', ' '));
        }
      } catch (_) {
        deadClients.add(client);
      }
    }
    for (final dead in deadClients) {
      _clients.remove(dead);
    }
  }

  Future<void> stop() async {
    for (final client in List<WebSocket>.from(_clients)) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
