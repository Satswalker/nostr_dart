import 'package:nostr_dart/src/relay.dart';
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
  group('pool.add:', () {
    test('can connect to a single relay', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr();
      final result = await nostr.pool.add('ws://localhost:${relay.port}');

      expect(result, isTrue);
      expect(nostr.pool.list.contains('ws://localhost:${relay.port}'), isTrue);
    });

    test('can connect to multiple relays', () async {
      final relay1 = await fakeRelay(onData: (message) {}, listen: false);
      final relay2 = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr();
      bool result = await nostr.pool.add('ws://localhost:${relay1.port}');
      expect(result, isTrue);
      result = await nostr.pool.add('ws://localhost:${relay2.port}');
      expect(result, isTrue);

      expect(nostr.pool.list.contains('ws://localhost:${relay1.port}'), isTrue);
      expect(nostr.pool.list.contains('ws://localhost:${relay2.port}'), isTrue);
    });

    test(
        'sends existing subscriptions to newly added relay when [autoSubscribe] is true',
        () async {
      final relay1 = await fakeRelay(onData: (message) {});
      final relay2 = await fakeRelay(onData: expectAsync1((message) {
        expect(
            message[2],
            equals(jsonEncode({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            })));
      }));

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay1.port}');
      nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      await nostr.pool
          .add('ws://localhost:${relay2.port}', autoSubscribe: true);
    });

    test('returns false if url is invalid', () async {
      final nostr = Nostr();
      bool result = await nostr.pool.add('localhost');
      expect(result, isFalse);
      expect(nostr.pool.list.length, equals(0));
    });
  });

  group('pool.remove:', () {
    test('removes a specified relay from the relay pool', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');
      expect(nostr.pool.list.contains('ws://localhost:${relay.port}'), isTrue);

      nostr.pool.remove('ws://localhost:${relay.port}');
      expect(nostr.pool.list.contains('ws://localhost:${relay.port}'), isFalse);
    });

    test('ignores an unknown url', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');
      expect(nostr.pool.list.length, equals(1));
      nostr.pool.remove('ws://example.com');
      expect(nostr.pool.list.length, equals(1));
    });
  });

  group('subscribe:', () {
    test('sends a valid subscription request', () async {
      const String expectedType = 'REQ';
      String expectedSubId = 'sub1';
      String expectedFilter = jsonEncode({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });

      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[0], equals(expectedType));
        expect(message[1], equals(expectedSubId));
        expect(message[2], equals(expectedFilter));
      }));

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');
      nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {}, expectedSubId);
    });

    test('can request and receive a single event', () async {
      final relay = await fakeRelay(
          onData: (message) {}, events: [TestConstants.relayEvent1]);

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');
      final subId = nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], expectAsync1((Event event) {
        expect(
            event.id,
            equals(
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"));
      }));
    });

    test('can request multiple subscriptions', () async {
      final relay = await fakeRelay(
          onData: (message) {},
          events: [TestConstants.relayEvent1, TestConstants.relayEvent2]);

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');

      final sub1 = nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], expectAsync1((Event event) {
        expect(
            event.id,
            equals(
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"));
      }));
      final sub2 = nostr.pool.subscribe([
        {
          "ids": [
            "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9"
          ]
        }
      ], expectAsync1((Event event) {
        expect(
            event.id,
            equals(
                "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9"));
      }));

      // THEN both subscriptions are recorded
      expect(nostr.pool.subscriptions.contains(sub1), isTrue);
      expect(nostr.pool.subscriptions.contains(sub2), isTrue);
    });

    test('request subscription message is sent to all connected relays',
        () async {
      final relay1 = await fakeRelay(onData: expectAsync1((message) {
        expect(
            message[2],
            equals(jsonEncode({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            })));
      }));
      final relay2 = await fakeRelay(onData: expectAsync1((message) {
        expect(
            message[2],
            equals(jsonEncode({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            })));
      }));

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay1.port}');
      await nostr.pool.add('ws://localhost:${relay2.port}');
      nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
    });

    test('can specify ID of new subscription', () async {
      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[1], equals('1234'));
      }));

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');
      nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {}, '1234');
    });

    test('updates existing subscription', () async {
      final relay = await fakeRelay(onData: (message) {});

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');
      const firstFilter = [
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ];
      const secondFilter = [
        {
          "ids": [
            "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9"
          ]
        }
      ];
      final subId = nostr.pool.subscribe(firstFilter, (event) {});
      nostr.pool.subscribe(secondFilter, (event) {}, subId);

      expect(nostr.pool.subscriptions.length, equals(1));
    });

    test(
        'only sends subscription requests to relays with read-only or read-write access',
        () async {
      bool ackRelay1 = false;
      bool ackRelay2 = false;
      bool ackRelay3 = false;
      final relay1 = await fakeRelay(onData: (message) {
        ackRelay1 = true;
      });
      final relay2 = await fakeRelay(onData: (message) {
        ackRelay2 = true;
      });
      final relay3 = await fakeRelay(onData: (message) {
        ackRelay3 = true;
      });

      final nostr = Nostr();
      await nostr.pool
          .add('ws://localhost:${relay1.port}'); // read-only by default
      await nostr.pool
          .add('ws://localhost:${relay2.port}', access: WriteAccess.readWrite);
      await nostr.pool
          .add('ws://localhost:${relay3.port}', access: WriteAccess.writeOnly);

      nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});

      await Future.delayed(Duration(seconds: 1));

      expect(ackRelay1, isTrue);
      expect(ackRelay2, isTrue);
      expect(ackRelay3, isFalse);
    });
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

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay.port}');
      final sub1 = nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      final sub2 = nostr.pool.subscribe([
        {
          "ids": [
            "ef340ed732776c226307bc3ed5d3d75ba0c9c784214557dbab0819a027d51ce9"
          ]
        }
      ], (event) {});
      nostr.pool.unsubscribe(sub1);

      expect(nostr.pool.subscriptions.contains(sub1), isFalse);
      expect(nostr.pool.subscriptions.contains(sub2), isTrue);
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

      final nostr = Nostr();
      await nostr.pool.add('ws://localhost:${relay1.port}');
      await nostr.pool.add('ws://localhost:${relay2.port}');
      final sub = nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      nostr.pool.unsubscribe(sub);

      expect(nostr.pool.subscriptions.contains(sub), isFalse);
    });

    // test('throws an ArgumentError if subscriptionId is unknown', () async {
    //   final relay = await fakeRelay(onData: (message) {}, listen: false);
    //   final nostr = Nostr();
    //   await nostr.pool.add('ws://localhost:${relay.port}');
    //   expect(() => nostr.unsubscribe('1234'), throwsArgumentError);
    // });
  });

  group('sendTextNote:', () {
    test('sends a valid text note event', () async {
      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.textNote));
        expect(event.content, equals("Hello World!"));
      }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool
          .add('ws://localhost:${relay.port}', access: WriteAccess.readWrite);
      nostr.sendTextNote("Hello World!");
    });

    test('sends a text note with tags', () async {
      final relay = await fakeRelay(onData: expectAsync1((message) {
        final event = Event.fromJson(message[1]);
        expect(
            event.tags,
            equals([
              ["e", TestConstants.id]
            ]));
      }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool
          .add('ws://localhost:${relay.port}', access: WriteAccess.readWrite);
      nostr.sendTextNote("Hello World!", [
        ["e", TestConstants.id]
      ]);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr();
      expect(() => nostr.sendTextNote('Hello World!'), throwsArgumentError);
    });

    test('only publishes events to relays with write or read-write access',
        () async {
      bool ackRelay1 = false;
      bool ackRelay2 = false;
      bool ackRelay3 = false;
      final relay1 = await fakeRelay(onData: (message) {
        ackRelay1 = true;
      });
      final relay2 = await fakeRelay(onData: (message) {
        ackRelay2 = true;
      });
      final relay3 = await fakeRelay(onData: (message) {
        ackRelay3 = true;
      });

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool
          .add('ws://localhost:${relay1.port}'); // read-only by default
      await nostr.pool
          .add('ws://localhost:${relay2.port}', access: WriteAccess.readWrite);
      await nostr.pool
          .add('ws://localhost:${relay3.port}', access: WriteAccess.writeOnly);

      nostr.sendTextNote("Hello Nostr!");

      await Future.delayed(Duration(seconds: 1));

      expect(ackRelay1, isFalse);
      expect(ackRelay2, isTrue);
      expect(ackRelay3, isTrue);
    });
  });

  group('sendMetaData:', () {
    test('sends a valid set_metadata event', () async {
      const String name = 'Satswalker';
      const String about = 'Just a pleb humbly stacking';
      const String picture =
          'https://avatars.githubusercontent.com/u/113159946?v=4';

      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.metaData));
        final metaData = jsonDecode(event.content);
        expect(metaData['name'], equals(name));
        expect(metaData['about'], equals(about));
        expect(metaData['picture'], equals(picture));
      }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool
          .add('ws://localhost:${relay.port}', access: WriteAccess.readWrite);
      nostr.sendMetaData(name: name, about: about, picture: picture);
    });

    test('metadata parameters are optional', () async {
      const about = 'Just a pleb humbly stacking';

      final relay = await fakeRelay(onData: expectAsync1((message) {
        final event = Event.fromJson(message[1]);
        final metaData = jsonDecode(event.content);
        expect(metaData.length, equals(1));
        expect(metaData['about'], equals(about));
      }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool
          .add('ws://localhost:${relay.port}', access: WriteAccess.readWrite);
      nostr.sendMetaData(about: about);
    });

    test('raises an exception if no metadata is given', () async {
      final nostr = Nostr(privateKey: TestConstants.privateKey);
      expect(() => nostr.sendMetaData(), throwsArgumentError);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr();
      expect(() => nostr.sendMetaData(name: 'Satswalker'), throwsArgumentError);
    });
  });

  group('recommendServer:', () {
    test('sends a valid recommend_server event', () async {
      const String url = 'wss://nostr.fmt.wiz.biz';

      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.recommendServer));
        expect(event.content, equals(url));
      }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool
          .add('ws://localhost:${relay.port}', access: WriteAccess.readWrite);
      nostr.recommendServer(url);
    });

    test('raises an exception if url is not a valid websocket', () {
      final nostr = Nostr(privateKey: TestConstants.privateKey);
      expect(() => nostr.recommendServer('wss//nostr.fmt.wiz.biz'),
          throwsArgumentError);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr();
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

      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.contactList));
        expect(event.tags, equals(tags));
        expect(event.content, equals(""));
      }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool
          .add('ws://localhost:${relay.port}', access: WriteAccess.readWrite);
      final contacts = ContactList.fromJson(tags);
      nostr.sendContactList(contacts);
    });

    test("raises an exception if the private key hasn't been set", () {
      final nostr = Nostr();
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
