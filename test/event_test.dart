import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:test/test.dart';
import 'package:bip340/bip340.dart' as schnorr;
import '../test/constants.dart';

void main() {
  group('fromJson:', () {
    test('Correctly maps JSON elements to the object model', () {
      const String json =
          '{ "id": "${TestConstants.id}", "pubkey": "${TestConstants.publicKey}", "created_at": ${TestConstants.timestamp}, "kind": ${TestConstants.kindTextNote}, "tags": [], "content": "${TestConstants.content}", "sig": "${TestConstants.sig}" }';
      final parsedJson = jsonDecode(json);
      final event = Event.fromJson(parsedJson);

      expect(event.id, TestConstants.id);
      expect(event.pubKey, TestConstants.publicKey);
      expect(event.createdAt, TestConstants.timestamp);
      expect(event.kind, 1);
      expect(event.tags, hasLength(0));
      expect(event.content, TestConstants.content);
      expect(event.sig, TestConstants.sig);
    });

    test('Correctly handles JSON data containing a single tag', () {
      const String json =
          '{ "id": "41f74d3ecaaf8e94fc9bfb8edc9919f466faf854df24aebe34f9930d4492e579", "pubkey": "${TestConstants.publicKey}", "created_at": ${TestConstants.timestamp}, "kind": ${TestConstants.kindTextNote}, "tags": [["e", "${TestConstants.id}"]], "content": "${TestConstants.content}", "sig": "9b5cd31e83b1344e93cf4896f81433fed628263ab63455f78ec62b1a4e0d6f5ab81a73b88ceb9318fa5b4d221441d3e1983660f95cb268dbe6576c0ae95e914c" }';
      final parsedJson = jsonDecode(json);
      final event = Event.fromJson(parsedJson);

      expect(event.tags[0], ["e", TestConstants.id]);
    });

    test('Correctly handles JSON data containing multiple tags', () {
      const String json =
          '{ "id": "3728dee0d6c22d7b1e83576e1e6884ad2a44746497eb14e367f1d7977b407986", "pubkey": "${TestConstants.publicKey}", "created_at": ${TestConstants.timestamp}, "kind": ${TestConstants.kindTextNote}, "tags": [["e", "${TestConstants.id}"], ["p", "${TestConstants.publicKey}"]], "content": "${TestConstants.content}", "sig": "7a53718c971bfda3d5fbdebf58581110c5ee981894e65c7983540be1c7a00b196fb3f392413fdd397816496574bc2e46126691754e38eb103c817d27ed1788e1" }';
      final parsedJson = jsonDecode(json);
      final event = Event.fromJson(parsedJson);

      expect(event.tags[1], ["p", TestConstants.publicKey]);
    });

    test('Raises an exception if "id" in JSON data is invalid', () {
      // id is not a hexadecimal string
      String json =
          '{ "id": "${TestConstants.idNotHex}", "pubkey": "${TestConstants.publicKey}", "created_at": ${TestConstants.timestamp}, "kind": ${TestConstants.kindTextNote}, "tags": [], "content": "${TestConstants.content}", "sig": "1234567812345678123456781234567812345678123456781234567812345678" }';
      var parsedJson = jsonDecode(json);
      expect(() => Event.fromJson(parsedJson), throwsArgumentError);

      // id isn't the correct length
      json =
          '{ "id": "${TestConstants.idWrongLength}", "pubkey": "${TestConstants.publicKey}", "created_at": ${TestConstants.timestamp}, "kind": ${TestConstants.kindTextNote}, "tags": [], "content": "${TestConstants.content}", "sig": "1234567812345678123456781234567812345678123456781234567812345678" }';
      parsedJson = jsonDecode(json);
      expect(() => Event.fromJson(parsedJson), throwsArgumentError);
    });

    test('Raises an exception if the event signature is incorrect', () {
      const String json =
          '{ "id": "${TestConstants.id}", "pubkey": "${TestConstants.publicKey}", "created_at": ${TestConstants.timestamp}, "kind": ${TestConstants.kindTextNote}, "tags": [], "content": "${TestConstants.content}", "sig": "1234567812345678123456781234567812345678123456781234567812345678" }';
      var parsedJson = jsonDecode(json);
      expect(() => Event.fromJson(parsedJson), throwsArgumentError);
    });
  });

  group('compose:', () {
    test('Returns a correct event object', () {
      const expectedId =
          "3e021e41017828b7ea873bf79f6c4f5f93fbef0cd6c4fa02ddaa27e15b11fbcf";

      // Clock stubbed to get a deterministic "id"
      final event = withClock(
        Clock.fixed(DateTime(2022)),
        () => Event(TestConstants.publicKey, TestConstants.kindTextNote,
            TestConstants.emptyTags, TestConstants.content),
      );

      // "id" is a SHA256 hash of event data
      expect(event.id, expectedId);
      expect(event.pubKey, TestConstants.publicKey);
      // Only need to check that "createdAt" is a number. Timestamp correctness
      // is verified in a subsequent test.
      expect(event.createdAt, isNotNaN);
      expect(event.kind, TestConstants.kindTextNote);
      expect(event.tags, hasLength(0));
      expect(event.content, TestConstants.content);
    });

    test('"createdAt" is a Unix timestamp of when the object was created', () {
      final now = clock.now();
      final expectedTimestamp = now.millisecondsSinceEpoch ~/ 1000;
      final event = Event(TestConstants.publicKey, TestConstants.kindTextNote,
          TestConstants.emptyTags, TestConstants.content);

      // 1s tolerance to avoid nuisance failures
      expect(event.createdAt, closeTo(expectedTimestamp, 1));
    });

    test('Raises an exception if the public key parameter is invalid', () {
      // Public key isn't a hexadecimal string
      expect(
          () => Event(TestConstants.keyNotHex, TestConstants.kindTextNote,
              TestConstants.emptyTags, TestConstants.content),
          throwsArgumentError);

      // Public key isn't the correct length
      expect(
          () => Event(TestConstants.keyWrongLength, TestConstants.kindTextNote,
              TestConstants.emptyTags, TestConstants.content),
          throwsArgumentError);
    });
  });

  group('sign:', () {
    test('signs event with the given private key', () {
      // Clock stubbed to get a deterministic "id"
      final event = withClock(
        Clock.fixed(DateTime(2022)),
        () => Event(TestConstants.publicKey, TestConstants.kindTextNote,
            TestConstants.emptyTags, TestConstants.content),
      );
      event.sign(TestConstants.privateKey);

      expect(
          schnorr.verify(TestConstants.publicKey, event.id, event.sig), isTrue);
    });

    test('raises an exception if the private key is not valid', () {
      final event = Event(TestConstants.publicKey, TestConstants.kindTextNote,
          TestConstants.emptyTags, TestConstants.content);
      event.sign(TestConstants.idNotHex);
    });
  });

  group('doProofOfWork:', () {}, skip: "TBD");
}
