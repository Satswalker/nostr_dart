import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_dart/src/relay_info_provider.mocks.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'constants.dart';
import 'fake_relay.dart';

void main() {
  group('connect/disconnect:', () {
    test('can connect, disconnect & reconnect to a relay', () async {
      // Relay fake
      final server = await fakeRelay(onData: (message) {});
      final url = 'ws://localhost:${server.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      // Client
      final relay = Relay(url, relayInfoProvider: mockRelayInfoProvider);

      expect(await relay.connect(), isTrue);
      await relay.disconnect();
      expect(relay.isConnected, isFalse);
      expect(await relay.connect(), isTrue);
      await relay.disconnect();
    });

    test('retrieves relay information on connection', () async {
      final server = await fakeRelay(onData: (message) {});
      final url = 'ws://localhost:${server.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "name": "my_relay",
                "description": "a fake relay",
                "pubkey": TestConstants.publicKey,
                "contact": "admin@example.com",
                "supported_nips": [15, 20],
                "software": "https://github.com/Satswalker/nostr_dart/",
                "version": "0.0.0"
              }));

      // Client
      final relay = Relay(url, relayInfoProvider: mockRelayInfoProvider);
      await relay.connect();
      expect(relay.info.name, equals("my_relay"));
      expect(relay.info.description, equals("a fake relay"));
      expect(relay.info.pubKey, equals(TestConstants.publicKey));
      expect(relay.info.contact, equals("admin@example.com"));
      expect(relay.info.nips, equals([15, 20]));
      expect(relay.info.software, "https://github.com/Satswalker/nostr_dart/");
      expect(relay.info.version, equals("0.0.0"));
    });
  });

  group('send:', () {
    test('automatically reconnects to relay if it is disconnected', () async {
      var hasNoPreviousConnection = true;

      // Fake relay disconnects automatically after first connection
      final server = await HttpServer.bind('localhost', 0);
      server.transform(WebSocketTransformer()).listen((webSocket) async {
        if (hasNoPreviousConnection) {
          await webSocket.close();
          hasNoPreviousConnection = false;
        } else {
          webSocket.listen(expectAsync1((message) {
            final json = jsonDecode(message);
            final type = json[0];
            if (type == "EVENT") {
              final event = Event.fromJson(json[1]);
              final response = ["OK", event.id, true, ""];
              webSocket.add(jsonEncode(response));
            }

            expect(message, jsonEncode(TestConstants.clientEvent1));
          }));
        }
      });
      final url = 'ws://localhost:${server.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      // Client
      final relay = Relay(url, relayInfoProvider: mockRelayInfoProvider);
      await relay.connect();
      await Future.delayed(const Duration(seconds: 1));
      await relay.send(jsonEncode(TestConstants.clientEvent1));
    });
  });
}
