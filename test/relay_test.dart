import 'package:nostr_dart/src/relay.dart';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('connect/disconnect:', () {
    test('can connect, disconnect & reconnect to a relay', () async {
      // Relay fake
      final server = await HttpServer.bind('localhost', 0);
      server.transform(WebSocketTransformer()).listen((webSocket) {});

      // Client
      final relay = Relay('ws://localhost:${server.port}');

      expect(await relay.connect(), isTrue);
      await relay.disconnect();
      expect(relay.isDisconnected, isTrue);
      expect(await relay.connect(), isTrue);
      relay.disconnect();
    });
  });
}
