A Nostr client library written in Dart.

## Features

Use this library in your Dart/Flutter app to:

- Connect to Nostr relays.
- Publish `set_metadata`, `text_note`, `recommend_server` and `contact_list` events to connected relays.
- Request events and subscribe to updates.

Supported Nostr Implementation Possibilities:

- [NIP-01: Basic protocol flow description](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [NIP-02: Contact List and Petnames](https://github.com/nostr-protocol/nips/blob/master/02.md)
- [NIP-13: Proof of Work](https://github.com/nostr-protocol/nips/blob/master/13.md)
- [NIP-15: End of Stored Events Notice](https://github.com/nostr-protocol/nips/blob/master/15.md)
- [NIP-20: Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)

## Getting started

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  nostr_dart: ^[version]
```

## Usage

Initialise `nostr_dart`:

```dart
import 'package:nostr_dart/nostr_dart.dart'

final nostr = Nostr.init(privateKey: [private key], powDifficulty: [difficulty]);
```

Add a relay:

```dart
await nostr.addRelay([relay url]);
```

Retrieve events from connected relays and subscribe to updates:

```dart
final subId = await nostr.subscribe([filters], [subscription id])
```

Read retrieved events:

```dart
for (Event event in nostr.events) {
    print('ID: ${event.id}. Content: ${event.content}');
}
```

Publish a text note:

```dart
final result = await nostr.sendTextNote([content], [tags]);
```

Publish metadata:

```dart
final result = await nostr.setMetaData(name: [name], about: [about], picture: [picture url]);
```

Publish server recommendation:

```dart
final result = await nostr.recommendServer([relay url]);
```

Publish a contact list:

```dart
final contacts = ContactList();
final contact = Contact.init(publicKey: [public key], url: [relay url], petname: [petname]);
contacts.add(contact);
final result = await nostr.sendContactList(contacts);
```

Remove an existing subscription:

```dart
nostr.unsubscribe([subscription id]);
```

Remove a connected relay:

```dart
nostr.removeRelay([relay url]);
```
