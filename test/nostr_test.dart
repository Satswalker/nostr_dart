import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:nostr_dart/src/relay_info_provider.mocks.dart';
import 'constants.dart';
import 'fake_relay.dart';

void main() async {
  group('pool.add:', () {
    test('can connect to a single relay', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      final result = await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));

      expect(result, isTrue);
      expect(nostr.pool.list.contains('ws://localhost:${relay.port}'), isTrue);
    });

    test('can connect to multiple relays', () async {
      final relay1 = await fakeRelay(onData: (message) {}, listen: false);
      final relay2 = await fakeRelay(onData: (message) {}, listen: false);
      final url1 = 'ws://localhost:${relay1.port}';
      final url2 = 'ws://localhost:${relay2.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url1))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url2))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      bool result = await nostr.pool
          .add(Relay(url1, relayInfoProvider: mockRelayInfoProvider));
      expect(result, isTrue);
      result = await nostr.pool
          .add(Relay(url2, relayInfoProvider: mockRelayInfoProvider));
      expect(result, isTrue);

      expect(nostr.pool.list.contains(url1), isTrue);
      expect(nostr.pool.list.contains(url2), isTrue);
    });

    test(
        'sends existing subscriptions to newly added relay when [autoSubscribe] is true',
        () async {
      final relay1 = await fakeRelay(onData: (message) {});
      final relay2 = await fakeRelay(onData: expectAsync1((message) {
        expect(
            message[2],
            equals({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            }));
      }));
      final url1 = 'ws://localhost:${relay1.port}';
      final url2 = 'ws://localhost:${relay2.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url1))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url2))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url1, relayInfoProvider: mockRelayInfoProvider));
      nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      await nostr.pool.add(
          Relay(url2, relayInfoProvider: mockRelayInfoProvider),
          autoSubscribe: true);
    });

    test('returns false if url is invalid', () async {
      final url = 'localhost';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      final nostr = Nostr();
      bool result = await nostr.pool.add(Relay(url));
      expect(result, isFalse);
      expect(nostr.pool.list.length, isZero);
    });

    test("returns false if relay doesn't support NIP-15 or NIP-20", () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [1, 2, 3, 16, 30]
              }));

      final nostr = Nostr();
      final result = await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));

      expect(result, isFalse);
      expect(nostr.pool.list.length, isZero);
    });
  });

  group('pool.remove:', () {
    test('removes a specified relay from the relay pool', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
      expect(nostr.pool.list.contains(url), isTrue);

      nostr.pool.remove(url);
      expect(nostr.pool.list.contains(url), isFalse);
    });

    test('ignores an unknown url', () async {
      final relay = await fakeRelay(onData: (message) {}, listen: false);
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
      expect(nostr.pool.list.length, equals(1));
      nostr.pool.remove('ws://example.com');
      expect(nostr.pool.list.length, equals(1));
    });
  });

  group('subscribe:', () {
    test('sends a valid subscription request', () async {
      const Map<String, dynamic> filter = {
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      };

      final relay = await fakeRelay(onData: expectAsync1((json) {
        expect(json[0], equals("REQ"));
        expect(json[1], equals("sub_1"));
        expect(json[2], equals(filter));
      }));
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
      nostr.pool.subscribe([filter], (event) {}, "sub_1");
    });

    test('can request and receive a single event', () async {
      final relay = await fakeRelay(
          onData: (message) {}, events: [TestConstants.relayEvent1]);
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
      nostr.pool.subscribe([
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));

      final sub1 = await nostr.pool.subscribe([
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
      final sub2 = await nostr.pool.subscribe([
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
            equals({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            }));
      }));
      final relay2 = await fakeRelay(onData: expectAsync1((message) {
        expect(
            message[2],
            equals({
              "ids": [
                "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
              ]
            }));
      }));
      final url1 = 'ws://localhost:${relay1.port}';
      final url2 = 'ws://localhost:${relay2.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url1))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url2))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url1, relayInfoProvider: mockRelayInfoProvider));
      await nostr.pool
          .add(Relay(url2, relayInfoProvider: mockRelayInfoProvider));
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
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
      final subId = await nostr.pool.subscribe(firstFilter, (event) {});
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
      final url1 = 'ws://localhost:${relay1.port}';
      final url2 = 'ws://localhost:${relay2.port}';
      final url3 = 'ws://localhost:${relay3.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url1))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url2))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url3))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool.add(Relay(url1,
          relayInfoProvider: mockRelayInfoProvider)); // read-only by default
      await nostr.pool.add(Relay(url2,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
      await nostr.pool.add(Relay(url3,
          access: WriteAccess.writeOnly,
          relayInfoProvider: mockRelayInfoProvider));

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

    test('can retrieve an event from a real relay', () async {
      final nostr = Nostr();
      await nostr.pool.add(Relay("wss://relay.damus.io"));
      await nostr.pool.add(Relay("wss://nostr-pub.wellorder.net"));
      await nostr.pool.add(Relay("wss://nostr.bitcoiner.social"));
      await nostr.pool.subscribe([
        {
          "authors": [
            "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
          ],
          "limit": 1
        }
      ], (event) {
        print(event.content);
      });
      await Future.delayed(Duration(seconds: 5));
    }, skip: "For exploratory testing only, connects to actual relays.");

    test('can subscribe > unsubscribe > subscribe', () async {
      final relay = await fakeRelay(
          onData: (message) {}, events: [TestConstants.relayEvent1]);
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
      await nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], expectAsync1((event) {
        expect(event.content, equals("The world says hello."));
      })).then((subId) => nostr.pool.unsubscribe(subId));
      await nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], expectAsync1((event) {
        expect(event.content, equals("The world says hello."));
      }));
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url, relayInfoProvider: mockRelayInfoProvider));
      final sub1 = await nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      final sub2 = await nostr.pool.subscribe([
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
      final url1 = 'ws://localhost:${relay1.port}';
      final url2 = 'ws://localhost:${relay2.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url1))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url2))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr();
      await nostr.pool
          .add(Relay(url1, relayInfoProvider: mockRelayInfoProvider));
      await nostr.pool
          .add(Relay(url2, relayInfoProvider: mockRelayInfoProvider));
      final sub = await nostr.pool.subscribe([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      nostr.pool.unsubscribe(sub);

      expect(nostr.pool.subscriptions.contains(sub), isFalse);
    });
  });

  group('sendTextNote:', () {
    test('sends a valid text note event', () async {
      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.textNote));
        expect(event.content, equals("Hello World!"));
      }));
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool.add(Relay(url,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool.add(Relay(url,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
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
      final url1 = 'ws://localhost:${relay1.port}';
      final url2 = 'ws://localhost:${relay2.port}';
      final url3 = 'ws://localhost:${relay3.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url1))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url2))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));
      when(mockRelayInfoProvider.get(url3))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool.add(Relay(url1,
          relayInfoProvider: mockRelayInfoProvider)); // read-only by default
      await nostr.pool.add(Relay(url2,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
      await nostr.pool.add(Relay(url3,
          access: WriteAccess.writeOnly,
          relayInfoProvider: mockRelayInfoProvider));

      nostr.sendTextNote("Hello Nostr!");

      await Future.delayed(Duration(seconds: 1));

      expect(ackRelay1, isFalse);
      expect(ackRelay2, isTrue);
      expect(ackRelay3, isTrue);
    });

    test('can send a text note to a real relay', () async {
      final nostr =
          Nostr(privateKey: TestConstants.privateKey, powDifficulty: 16);
      await nostr.pool
          .add(Relay("wss://relay.damus.io", access: WriteAccess.readWrite));
      final event = nostr.sendTextNote("Hello Nostr!");
      nostr.pool.subscribe([
        {
          "ids": [event.id]
        }
      ], expectAsync1((event) {
        expect(event.content, equals("Hello Nostr"));
      }));
    }, skip: "For exploratory testing only, connects to actual relays.");
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool.add(Relay(url,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool.add(Relay(url,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
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
      const String recommendedUrl = 'wss://nostr.fmt.wiz.biz';

      final relay = await fakeRelay(onData: expectAsync1((message) {
        expect(message[0], "EVENT");
        final event = Event.fromJson(message[1]);
        expect(event.kind, equals(EventKind.recommendServer));
        expect(event.content, equals(recommendedUrl));
      }));
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool.add(Relay(url,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
      nostr.recommendServer(recommendedUrl);
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
      final url = 'ws://localhost:${relay.port}';
      final mockRelayInfoProvider = MockRelayInfoProvider();
      when(mockRelayInfoProvider.get(url))
          .thenAnswer((_) async => RelayInfo.fromJson({
                "supported_nips": [15, 20]
              }));

      final nostr = Nostr(privateKey: TestConstants.privateKey);
      await nostr.pool.add(Relay(url,
          access: WriteAccess.readWrite,
          relayInfoProvider: mockRelayInfoProvider));
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
