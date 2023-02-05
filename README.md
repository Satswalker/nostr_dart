[![Dart](https://github.com/Satswalker/nostr_dart/actions/workflows/dart.yml/badge.svg)](https://github.com/Satswalker/nostr_dart/actions/workflows/dart.yml)

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

final nostr = Nostr(privateKey: [private key], powDifficulty: [difficulty]);
```

Add a relay:

```dart
await nostr.pool.add([Relay URL]);
```

Retrieve events from connected relays and subscribe to updates:

```dart
final subId = nostr.pool.subscribe([List of filters], [onEvent callback], [Subscription ID]);
```

Publish a text note:

```dart
nostr.sendTextNote([content], [tags]);
```

Publish metadata:

```dart
nostr.sendMetaData(name: [name], about: [about], picture: [picture url]);
```

Publish server recommendation:

```dart
nostr.recommendServer([Relay URL]);
```

Publish a contact list:

```dart
final contacts = ContactList();
final contact = Contact(publicKey: [public key], url: [relay url], petname: [petname]);
contacts.add(contact);
nostr.sendContactList(contacts);
```

Publish an arbitrary event:

```dart
final event = Event(publicKey, 1, [], "A beautifully handcrafted event");
nostr.sendEvent(event);
```

Remove an existing subscription:

```dart
nostr.pool.unsubscribe([subscription ID]);
```

Remove a connected relay:

```dart
nostr.pool.remove([Relay URL]);
```

## Contributing

Pull requests are welcome. Please write tests to cover your new feature.
