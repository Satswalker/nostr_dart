import 'package:test/test.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'dart:io';
import 'dart:convert';
import 'constants.dart';

Future<HttpServer> fakeRelay(
    {required Function(dynamic json) onData,
    List<dynamic> events = const [],
    bool listen = true}) async {
  final relay = await HttpServer.bind('localhost', 0);
  if (listen) {
    relay.transform(WebSocketTransformer()).listen(expectAsync1((webSocket) {
      webSocket.listen((encodedMessage) {
        final message = jsonDecode(encodedMessage);
        onData(message);
        final type = message[0];
        if (type == "EVENT") {
          final event = Event.fromJson(message[1]);
          final response = ["OK", event.id, true, ""];
          webSocket.add(jsonEncode(response));
        } else if (type == "REQ") {
          final subId = message[1];
          for (dynamic event in events) {
            List<dynamic> response = [event[0], subId, event[2]];
            webSocket.add(jsonEncode(response));
          }
          final endNotice = ["EOSE", subId];
          webSocket.add(jsonEncode(endNotice));
        }
      });
    }));
  } else {
    relay.transform(WebSocketTransformer());
  }
  return relay;
}

void main() async {
  group('addRelay:', () {
    test('can connect to a single relay', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');

      expect(nostr.relayCount(), equals(1));
      expect(nostr.hasRelay('ws://localhost:${relay.port}'), isTrue);
    });

    test('can connect to multiple relays', () async {
      final relay1 = await fakeRelay(onData: (message) {}, listen: false);
      final relay2 = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay1.port}');
      await nostr.addRelay('ws://localhost:${relay2.port}');

      expect(nostr.relayCount(), equals(2));
      expect(nostr.hasRelay('ws://localhost:${relay1.port}'), isTrue);
      expect(nostr.hasRelay('ws://localhost:${relay2.port}'), isTrue);
    });

    test('sends existing subscriptions to newly added relay', () async {
      final relay1 = await fakeRelay(onData: (message) {});
      final relay2 = await fakeRelay(onData: (message) {
        expect(
            message[2],
            equals({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            }));
      });

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay1.port}');
      await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      await nostr.addRelay('ws://localhost:${relay2.port}');
    });

    test('throws an exception if url is invalid', () {
      final nostr = Nostr.init();
      expect(() => nostr.addRelay('localhost'),
          throwsA(isA<WebSocketException>()));
      expect(nostr.relayCount(), equals(0));
    });
  });

  group('removeRelay:', () {
    test('removes a specified relay from the relay pool', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      expect(nostr.relayCount(), equals(1));
      expect(nostr.hasRelay('ws://localhost:${relay.port}'), isTrue);

      nostr.removeRelay('ws://localhost:${relay.port}');
      expect(nostr.relayCount(), equals(0));
      expect(nostr.hasRelay('ws://localhost:${relay.port}'), isFalse);
    });

    test('throws an ArgumentError if url is unknown', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr.init();
      expect(() => nostr.removeRelay('ws://localhost:${relay.port}'),
          throwsArgumentError);
    });
  });

  group('subscribe:', () {
    test('sends a valid subscription request', () async {
      const String expectedType = 'REQ';
      String expectedSubId = 'sub1';
      const Map<String, dynamic> expectedFilter = {
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      };

      final relay = await fakeRelay(onData: (message) {
        expect(message[0], equals(expectedType));
        expect(message[1], equals(expectedSubId));
        expect(message[2], equals(expectedFilter));
      });

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      }, expectedSubId);
    });

    test('can request and receive a single event', () async {
      final relay = await fakeRelay(
          onData: (message) {}, events: [TestConstants.relayEvent1]);

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      final subId = await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });

      expect(nostr.hasSubscription(subId), isTrue);
      expect(nostr.eventCount(), equals(1));
    });

    test('discards duplicate events received', () async {
      final relay1 = await fakeRelay(
          onData: (message) {}, events: [TestConstants.relayEvent1]);
      final relay2 = await fakeRelay(
          onData: (message) {}, events: [TestConstants.relayEvent1]);

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay1.port}');
      await nostr.addRelay('ws://localhost:${relay2.port}');
      await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });

      expect(nostr.eventCount(), equals(1));
    });

    test('discards events received that were not subscribed for', () async {
      final relay = await HttpServer.bind('localhost', 0);
      relay.transform(WebSocketTransformer()).listen((webSocket) {
        webSocket.add(jsonEncode(TestConstants.relayEvent1));
      });

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      await Future.delayed(const Duration(seconds: 1), () {});
      expect(nostr.eventCount(), equals(0));
    });

    test('can request multiple subscriptions', () async {
      final relay = await fakeRelay(
          onData: (message) {},
          events: [TestConstants.relayEvent1, TestConstants.relayEvent2]);

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');

      final sub1 = await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      final sub2 = await nostr.subscribe({
        "ids": [
          "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9"
        ]
      });

      // THEN both subscriptions are recorded
      expect(nostr.hasSubscription(sub1), isTrue);
      expect(nostr.hasSubscription(sub2), isTrue);

      // AND received events queue has 2 events
      expect(nostr.eventCount(), equals(2));
    });

    test('request subscription message is sent to all connected relays',
        () async {
      final relay1 = await fakeRelay(onData: (message) {
        expect(
            message[2],
            equals({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            }));
      });
      final relay2 = await fakeRelay(onData: (message) {
        expect(
            message[2],
            equals({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            }));
      });

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay1.port}');
      await nostr.addRelay('ws://localhost:${relay2.port}');
      await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
    });

    test('can specify ID of new subscription', () async {
      final relay = await fakeRelay(onData: (message) {
        expect(message[1], equals('1234'));
      });

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      }, '1234');
    });

    test('updates existing subscription', () async {
      final relay = await fakeRelay(onData: (message) {});

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      const firstFilter = {
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      };
      const secondFilter = {
        "ids": [
          "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9"
        ]
      };
      final subId = await nostr.subscribe(firstFilter);
      await nostr.subscribe(secondFilter, subId);

      expect(nostr.subscriptionCount(), equals(1));
      expect(nostr.getSubscription(subId), secondFilter);
    });

    test('throws an ArgumentError if filters are invalid', () {},
        skip: 'Not implemented');
  });

  group('unsubscribe:', () {
    test('can remove an existing subscription', () async {
      int count = 1;
      final relay = await fakeRelay(onData: (message) {
        // Subscription close will be the 3rd message received.
        // The 1st two messages will be the initial subscription requests.
        if (count >= 3) {
          expect(message[0], equals("CLOSE"));
        }
        count++;
      });

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      final sub1 = await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      final sub2 = await nostr.subscribe({
        "ids": [
          "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9"
        ]
      });
      nostr.unsubscribe(sub1);

      expect(nostr.hasSubscription(sub1), isFalse);
      expect(nostr.hasSubscription(sub2), isTrue);
    });

    test('close subscription message is sent to each relay', () async {
      int count1 = 1;
      int count2 = 1;
      final relay1 = await fakeRelay(onData: (message) {
        // Subscription close will be the 2nd received message after
        // the initial subscription request.
        if (count1 >= 2) {
          expect(message[0], equals('CLOSE'));
        }
        count1++;
      });
      final relay2 = await fakeRelay(onData: (message) {
        if (count2 >= 2) {
          expect(message[0], equals('CLOSE'));
        }
        count2++;
      });

      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay1.port}');
      await nostr.addRelay('ws://localhost:${relay2.port}');
      final sub = await nostr.subscribe({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      nostr.unsubscribe(sub);

      expect(nostr.hasSubscription(sub), isFalse);
    });

    test('throws an ArgumentError if subscriptionId is unknown', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);
      final nostr = Nostr.init();
      await nostr.addRelay('ws://localhost:${relay.port}');
      expect(() => nostr.unsubscribe('1234'), throwsArgumentError);
    });
  });

  group('sendTextNote:', () {
    test('sends a valid text note event', () async {
      final relay = await fakeRelay(onData: (message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.textNote));
        expect(event.content, equals("Hello World!"));
      });

      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      await nostr.addRelay('ws://localhost:${relay.port}');
      await nostr.sendTextNote("Hello World!");
    });

    test('sends a text note with tags', () async {
      final relay = await fakeRelay(onData: (message) {
        final event = Event.fromJson(message[1]);
        expect(
            event.tags,
            equals([
              ["e", TestConstants.id]
            ]));
      });

      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      await nostr.addRelay('ws://localhost:${relay.port}');
      await nostr.sendTextNote("Hello World!", [
        ["e", TestConstants.id]
      ]);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr.init();
      expect(() => nostr.sendTextNote('Hello World!'), throwsArgumentError);
    });
  });

  group('setMetaData:', () {
    test('sends a valid set_metadata event', () async {
      const String name = 'Satswalker';
      const String about = 'Just a pleb humbly stacking';
      const String picture =
          'https://avatars.githubusercontent.com/u/113159946?v=4';

      final relay = await fakeRelay(onData: (message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.setMetaData));
        final metaData = jsonDecode(event.content);
        expect(metaData['name'], equals(name));
        expect(metaData['about'], equals(about));
        expect(metaData['picture'], equals(picture));
      });

      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      await nostr.addRelay('ws://localhost:${relay.port}');
      await nostr.setMetaData(name: name, about: about, picture: picture);
    });

    test('metadata parameters are optional', () async {
      const about = 'Just a pleb humbly stacking';

      final relay = await fakeRelay(onData: (message) {
        final event = Event.fromJson(message[1]);
        final metaData = jsonDecode(event.content);
        expect(metaData.length, equals(1));
        expect(metaData['about'], equals(about));
      });

      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      await nostr.addRelay('ws://localhost:${relay.port}');
      await nostr.setMetaData(about: about);
    });

    test('raises an exception if no metadata is given', () async {
      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      expect(() => nostr.setMetaData(), throwsArgumentError);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr.init();
      expect(() => nostr.setMetaData(name: 'Satswalker'), throwsArgumentError);
    });
  });

  group('recommendServer:', () {
    test('sends a valid recommend_server event', () async {
      const String url = 'wss://nostr.fmt.wiz.biz';

      final relay = await fakeRelay(onData: (message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.recommendServer));
        expect(event.content, equals(url));
      });

      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      await nostr.addRelay('ws://localhost:${relay.port}');
      await nostr.recommendServer(url);
    });

    test('raises an exception if url is not a valid websocket', () {
      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      expect(() => nostr.recommendServer('wss//nostr.fmt.wiz.biz'),
          throwsArgumentError);
    });

    test('raises an exception if url is a Tor address', () {
      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      expect(
          () => nostr.recommendServer(
              'ws://jgqaglhautb4k6e6i2g34jakxiemqp6z4wynlirltuukgkft2xuglmqd.onion'),
          throwsArgumentError);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr.init();
      expect(() => nostr.recommendServer('wss//nostr.fmt.wiz.biz'),
          throwsArgumentError);
    });
  });

  group('sendContactList:', () {
    test('sends a valid contact list event', () async {
      const tags = [
        [
          "p",
          "253d92d92ab577f616797b3660f5b0d0f5a4ecd77a057891fea798c16b2abdce",
          "",
          ""
        ]
      ];

      final relay = await fakeRelay(onData: (message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.contactList));
        expect(event.tags, equals(tags));
        expect(event.content, equals(""));
      });

      final nostr = Nostr.init(privateKey: TestConstants.privateKey);
      await nostr.addRelay('ws://localhost:${relay.port}');
      final contacts = ContactList.fromJson(tags);
      await nostr.sendContactList(contacts);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr.init();
      final contacts = ContactList.fromJson([
        [
          "p",
          "253d92d92ab577f616797b3660f5b0d0f5a4ecd77a057891fea798c16b2abdce",
          "",
          ""
        ]
      ]);
      expect(() => nostr.sendContactList(contacts), throwsArgumentError);
    });
  });
}
