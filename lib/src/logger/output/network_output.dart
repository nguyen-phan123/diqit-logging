import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';

class NetworkOutput extends LogOutput {
  final int port;
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  List<OutputEvent> Function()? _bufferGetter;
  void Function()? _onClear;
  RawDatagramSocket? _mdnsSocket;
  String? _hostname;

  NetworkOutput({this.port = 9229});

  int get actualPort => _server?.port ?? 0;

  bool get isRunning => _server != null;

  Future<void> start({
    List<OutputEvent> Function()? bufferGetter,
    void Function()? onClear,
  }) async {
    _bufferGetter = bufferGetter;
    _onClear = onClear;
    _hostname = Platform.localHostname;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    _startMdns();

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

    ws.listen(
      (message) {
        if (message is String) {
          _handleCommand(ws, message.trim());
        }
      },
      onError: (_) => _clients.remove(ws),
    );

    ws.done.then((_) => _clients.remove(ws));
  }

  void _handleCommand(WebSocket ws, String message) {
    if (!message.startsWith('!')) return;

    switch (message) {
      case '!clear':
        _onClear?.call();
        _sendLine(ws, '!OK Buffer cleared');
        break;
      case '!copy':
        _sendCopy(ws);
        break;
      case '!help':
        _sendHelp(ws);
        break;
    }
  }

  void _sendCopy(WebSocket ws) {
    final buffer = _bufferGetter?.call();
    _sendLine(ws, '--- BEGIN LOG COPY ---');
    if (buffer != null) {
      for (final event in buffer) {
        for (final line in event.lines) {
          _sendLine(ws, line);
        }
      }
    }
    _sendLine(ws, '--- END LOG COPY ---');
  }

  void _sendHelp(WebSocket ws) {
    _sendLine(ws, '!clear — Clear the log history buffer');
    _sendLine(ws, '!copy  — Export all buffered logs as text');
    _sendLine(ws, '!help  — Show this help');
  }

  void _sendLine(WebSocket ws, String line) {
    try {
      ws.add(line.replaceAll('\n', ' '));
    } catch (_) {
      _clients.remove(ws);
    }
  }

  void _startMdns() {
    _mdnsSocket?.close();
    try {
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true)
          .then((RawDatagramSocket socket) {
        _mdnsSocket = socket;
        _announceMdns(socket, ttl: 120);
      }).catchError((_) {
        _mdnsSocket = null;
      });
    } catch (_) {
      _mdnsSocket = null;
    }
  }

  void _announceMdns(RawDatagramSocket socket, {required int ttl}) {
    final packet = _buildMdnsPacket(ttl: ttl);
    try {
      socket.send(
        packet,
        InternetAddress('224.0.0.251'),
        5353,
      );
    } catch (_) {
      // mDNS unavailable — non-critical
    }
  }

  void _sendGoodbyeMdns() {
    if (_mdnsSocket == null) return;
    _announceMdns(_mdnsSocket!, ttl: 0);
    _mdnsSocket!.close();
    _mdnsSocket = null;
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
    _sendGoodbyeMdns();
    for (final client in List<WebSocket>.from(_clients)) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  // --- mDNS packet construction ---

  static String get _serviceName => '_diqit-log._tcp.local';
  String get _instanceName => '$_hostname.$_serviceName';
  String get _targetName => '$_hostname.local';

  Uint8List _buildMdnsPacket({required int ttl}) {
    final data = BytesBuilder();

    // DNS Header
    _addBytes(data, _u16(0)); // ID
    _addBytes(data, _u16(0x8400)); // Flags: response, authoritative
    _addBytes(data, _u16(0)); // QDCOUNT
    _addBytes(data, _u16(3)); // ANCOUNT
    _addBytes(data, _u16(0)); // NSCOUNT
    _addBytes(data, _u16(0)); // ARCOUNT

    // PTR: _diqit-log._tcp.local → instance
    _addPtr(data, _serviceName, _instanceName, ttl);
    // SRV: instance → hostname.local:port
    _addSrv(data, _instanceName, _targetName, port, ttl);
    // A: hostname.local → 0.0.0.0 (resolved from source addr)
    _addA(data, _targetName, ttl);

    return Uint8List.fromList(data.toBytes());
  }

  static void _addPtr(
      BytesBuilder buf, String service, String instance, int ttl) {
    _addDnsName(buf, service);
    _addBytes(buf, _u16(12)); // TYPE = PTR
    _addBytes(buf, _u16(0x8001)); // CLASS = IN, cache-flush
    _addBytes(buf, _u32(ttl));
    final rd = BytesBuilder();
    _addDnsName(rd, instance);
    final rdata = rd.toBytes();
    _addBytes(buf, _u16(rdata.length));
    _addBytes(buf, rdata);
  }

  static void _addSrv(
      BytesBuilder buf, String instance, String target, int port, int ttl) {
    _addDnsName(buf, instance);
    _addBytes(buf, _u16(33)); // TYPE = SRV
    _addBytes(buf, _u16(0x8001)); // CLASS = IN, cache-flush
    _addBytes(buf, _u32(ttl));
    final rd = BytesBuilder();
    _addBytes(rd, _u16(0)); // priority
    _addBytes(rd, _u16(0)); // weight
    _addBytes(rd, _u16(port));
    _addDnsName(rd, target);
    final rdata = rd.toBytes();
    _addBytes(buf, _u16(rdata.length));
    _addBytes(buf, rdata);
  }

  static void _addA(BytesBuilder buf, String name, int ttl) {
    _addDnsName(buf, name);
    _addBytes(buf, _u16(1)); // TYPE = A
    _addBytes(buf, _u16(0x8001)); // CLASS = IN, cache-flush
    _addBytes(buf, _u32(ttl));
    _addBytes(buf, _u16(4)); // RDLENGTH
    _addBytes(buf, [0, 0, 0, 0]); // IP (resolved from packet src)
  }

  static void _addDnsName(BytesBuilder buf, String name) {
    for (final part in name.split('.')) {
      final bytes = utf8.encode(part);
      buf.addByte(bytes.length);
      buf.add(bytes);
    }
    buf.addByte(0);
  }

  static void _addBytes(BytesBuilder buf, List<int> bytes) {
    buf.add(bytes);
  }

  static List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
  static List<int> _u32(int v) => [
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
      ];
}
