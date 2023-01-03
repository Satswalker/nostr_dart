import 'package:nostr/src/relay.dart';
import 'package:nostr/src/subscription.dart';
import 'package:nostr/src/event.dart';
import '../test/constants.dart';
import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:string_validator/string_validator.dart' as hex_string;
import 'package:nostr/src/util.dart';

void main() {
  group('connect/disconnect:', () {
    test('can connect, disconnect & reconnect to a relay', () async {
      var messageSent = 'Tick';

      // Relay fake
      final server = await HttpServer.bind('localhost', 0);
      server.transform(WebSocketTransformer()).listen((webSocket) {
        webSocket.add(messageSent);
      });

      // Client
      final relay = Relay.init('ws://localhost:${server.port}');
      relay.listen(expectAsync1((messageReceived) {
        expect(messageReceived, equals(messageSent));
        messageSent = 'Tock';
      }, count: 2));
      await relay.connect();
      relay.disconnect();
      await relay.connect();
      relay.disconnect();
    });
  });

  group('subscribe:', () {
    test('relay receives a correctly formatted subscription request', () async {
      // Simulate a relay to listen for subscription request from client
      final server = await HttpServer.bind('localhost', 0);
      server.transform(WebSocketTransformer()).listen(expectAsync1((webSocket) {
        webSocket.listen(expectAsync1((request) {
          final json = jsonDecode(request);
          // Check message type
          expect(json[0], equals('REQ'));
          // Check subscription ID format
          expect(json[1].length, equals(64));
          expect(hex_string.isHexadecimal(json[1]), isTrue);
          // Check received filters
          expect(
              json[2],
              equals({
                "ids": [
                  "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
                ]
              }));
          webSocket.close();
        }));
      }));

      // Client side
      final relay = Relay.init('ws://localhost:${server.port}');
      await relay.connect();
      relay.listen((message) {});
      final subscription = Subscription.init({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      relay.subscribe(subscription);
    });
  });

  group('unsubscribe:', () {
    test('relay receives a correctly formatted subscription close request',
        () async {
      final mockSubId = getRandomHexString();

      // Simulate a relay to listen for subscription request from client
      final server = await HttpServer.bind('localhost', 0);
      server.transform(WebSocketTransformer()).listen(expectAsync1((webSocket) {
        webSocket.listen(expectAsync1((request) {
          final json = jsonDecode(request);
          // Check message type
          expect(json[0], equals('CLOSE'));
          // Check subscription ID
          expect(json[1], equals(mockSubId));
          webSocket.close();
        }));
      }));

      // Client side
      final relay = Relay.init('ws://localhost:${server.port}');
      await relay.connect();
      relay.listen((message) {});
      relay.unsubscribe(mockSubId);
    });
  });

  group('post:', () {
    test('sends a valid event to the relay', () async {
      // Relay fake
      final server = await HttpServer.bind('localhost', 0);
      server.transform(WebSocketTransformer()).listen(expectAsync1((webSocket) {
        webSocket.listen(expectAsync1((message) {
          final json = jsonDecode(message);
          final receivedEvent = Event.fromJson(json[1]);
          expect(receivedEvent.content, equals(TestConstants.content));
          webSocket.close();
        }));
      }));

      // Client side
      final event = Event.compose(
          TestConstants.publicKey,
          TestConstants.kindTextNote,
          TestConstants.emptyTags,
          TestConstants.content);
      event.sign(TestConstants.privateKey);
      final relay = Relay.init('ws://localhost:${server.port}');
      await relay.connect();
      relay.post(event);
    });
  });
}
