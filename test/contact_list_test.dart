import 'package:test/test.dart';
import 'package:nostr_dart/src/contact_list.dart';

void main() {
  final alice = Contact(
      publicKey:
          "253d92d92ab577f616797b3660f5b0d0f5a4ecd77a057891fea798c16b2abdce",
      url: "wss://alicerelay.com/",
      petname: "alice");
  final bob = Contact(
      publicKey:
          "5b2e69d67a1e8e6df848bc9680bf4ecd6ec33c79121aea97112cff1bad1a4169",
      url: "wss://bobrelay.com/nostr",
      petname: "bob");
  final carol = Contact(
      publicKey:
          "18d85302b8195fec72f2c11efe5fc8ea22ed0f6dfc59ae5286a2cb29aed1664d",
      url: "ws://carolrelay.com/ws",
      petname: "carol");

  group('fromJson', () {
    test('populates a new contact list from a JSON array of event tags', () {
      final tags = [
        ["p", alice.publicKey, alice.url, alice.petname],
        ["p", bob.publicKey, bob.url, bob.petname],
        ["p", carol.publicKey, carol.url, carol.petname]
      ];
      final contactList = ContactList.fromJson(tags);
      var contact = contactList.get(alice.publicKey);
      expect(contact.publicKey, equals(alice.publicKey));
      contact = contactList.get(bob.publicKey);
      expect(contact.url, equals(bob.url));
      contact = contactList.get(carol.publicKey);
      expect(contact.petname, equals(carol.petname));
    });
  });

  group('toJson:', () {
    test('returns the contact list as a JSON array of event tags', () {
      final contactList = ContactList();
      contactList.add(alice);
      contactList.add(bob);
      contactList.add(carol);
      List<dynamic> tags = contactList.toJson();
      expect(
          tags,
          equals([
            ["p", alice.publicKey, alice.url, alice.petname],
            ["p", bob.publicKey, bob.url, bob.petname],
            ["p", carol.publicKey, carol.url, carol.petname]
          ]));
    });
  });

  group('add & get:', () {
    test('can add and retrieve contacts', () {
      final contactList = ContactList();
      contactList.add(carol);
      contactList.add(alice);
      final contact = contactList.get(alice.publicKey);
      expect(contact.petname, equals(alice.petname));
    });

    test('raises an exception if the requested contact is unknown', () {
      final contactList = ContactList();
      expect(() => contactList.get(bob.publicKey), throwsArgumentError);
    });

    test('can update an existing contact', () {
      final contactList = ContactList();
      contactList.add(alice);
      final newAlice =
          Contact(publicKey: alice.publicKey, url: alice.url, petname: "ally");
      contactList.add(newAlice);
      final contact = contactList.get(alice.publicKey);
      expect(contact.petname, equals("ally"));
    });
  });

  group('remove:', () {
    test('removes contact returning the removed contact', () {
      final contactList = ContactList();
      contactList.add(bob);
      expect(() => contactList.get(bob.publicKey), returnsNormally);
      final contact = contactList.remove(bob.publicKey);
      expect(contact.petname, equals(bob.petname));
      expect(() => contactList.get(bob.publicKey), throwsArgumentError);
    });

    test('raises an exception if the requested contact is unknown', () {
      final contactList = ContactList();
      expect(() => contactList.remove(bob.publicKey), throwsArgumentError);
    });
  });

  group('iterator:', () {
    test('ContactList can be iterated over', () {
      const expectedNames = ["alice", "bob", "carol"];
      final contactList = ContactList();
      contactList.add(alice);
      contactList.add(bob);
      contactList.add(carol);
      int i = 0;
      for (Contact contact in contactList) {
        expect(contact.petname, equals(expectedNames[i++]));
      }
    });
  });
}
