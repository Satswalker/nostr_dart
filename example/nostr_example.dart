import 'package:nostr_dart/nostr_dart.dart';

void main() async {
  // Generate a new private key
  final privateKey = generatePrivateKey();
  final publicKey = getPublicKey(privateKey);
  print('Private Key: $privateKey\nPublic Key: $publicKey\n');

  // The client API is provided by the Nostr class.
  final nostr = Nostr.init(privateKey: privateKey, powDifficulty: 16);

  // Connect to a Nostr relay. This is an asynchronous operation so
  // consider using the `await` keyword.
  const relayUrl = 'wss://relay.nostr.info';
  await nostr.addRelay(relayUrl);

  // Retrieve an event
  final subId = await nostr.subscribe({
    "ids": ["00002de2e06d9630b58df3bc4f10e27febbc089286b5498bbbcac9baef3dd45a"]
  });

  // Read received events
  for (Event event in nostr.events) {
    print('${event.content}\n');
  }

  // Publish a text note and confirm the operation was sucessful
  var result = await nostr.sendTextNote('Hello Nostr!');
  if (result.success) {
    print('winning!');
  }

  // Publish a relay recommendation
  await nostr.recommendServer('wss://nostr.onsats.org');

  // Update metadata
  await nostr.setMetaData(name: "my-name");

  // Publish a contact list
  final contacts = ContactList();
  final alice = Contact.init(
      publicKey:
          "253d92d92ab577f616797b3660f5b0d0f5a4ecd77a057891fea798c16b2abdce",
      url: "wss://alicerelay.com/",
      petname: "alice");
  contacts.add(alice);
  await nostr.sendContactList(contacts);

  // Remove subscription and disconnect from the relay
  nostr.unsubscribe(subId);
  nostr.removeRelay(relayUrl);
}
