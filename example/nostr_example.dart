import 'package:nostr_dart/nostr.dart';

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

  // Retrieve events by creating a subscription
  print(
      'Requesting message ID 88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6\n');
  final subId = await nostr.subscribe({
    "ids": ["00002de2e06d9630b58df3bc4f10e27febbc089286b5498bbbcac9baef3dd45a"]
  });
  for (Event event in nostr.events) {
    print('${event.content}\n');
  }
  // Publish a text note
  print('Sending text note');
  final result = await nostr.sendTextNote('Hello Nostr!');
  print('Text note status: ${result.success}. ID: ${result.id}');

  // Remove subscription and disconnect from the relay
  nostr.unsubscribe(subId);
  nostr.removeRelay(relayUrl);
}
