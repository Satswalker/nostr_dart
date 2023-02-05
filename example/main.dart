import 'package:nostr_dart/nostr_dart.dart';
import 'package:nostr_dart/src/relay.dart';

void main() async {
  // Generate a new private key
  final privateKey = generatePrivateKey();
  final publicKey = getPublicKey(privateKey);
  print('Private Key: $privateKey\nPublic Key: $publicKey\n');

  // The client API is provided by the Nostr class.
  final nostr = Nostr(privateKey: privateKey, powDifficulty: 16);

  // Connect to a Nostr relay. This is an asynchronous operation so
  // consider using the `await` keyword.
  const relayUrl = 'wss://relay.nostr.info';
  await nostr.pool.add(relayUrl, access: WriteAccess.readWrite);

  // Retrieve an event
  final subId = nostr.pool.subscribe([
    {
      "ids": [
        "00002de2e06d9630b58df3bc4f10e27febbc089286b5498bbbcac9baef3dd45a"
      ]
    }
  ], (event) {});

  // Publish a text note
  nostr.sendTextNote('Hello Nostr!');

  // Publish a relay recommendation
  nostr.recommendServer('wss://nostr.onsats.org');

  // Update metadata
  nostr.sendMetaData(name: "my-name");

  // Publish a contact list
  final contacts = ContactList();
  final alice = Contact(
      publicKey:
          "253d92d92ab577f616797b3660f5b0d0f5a4ecd77a057891fea798c16b2abdce",
      url: "wss://alicerelay.com/",
      petname: "alice");
  contacts.add(alice);
  nostr.sendContactList(contacts);

  // Publish an arbitrary event
  final event = Event(publicKey, 1, [], "A beautifully handcrafted event");
  nostr.sendEvent(event);

  // Remove subscription and disconnect from the relay
  nostr.pool.unsubscribe(subId);
  nostr.pool.remove(relayUrl);
}
