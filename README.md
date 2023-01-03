A Nostr client library written in Dart.

## Features

Use this library in your Dart/Flutter app to:

- Connect to Nostr relays.
- Publish `set_metadata`, `text_note` and `recommend_server` events to connected relays.
- Request events and subscribe to updates.

Currently implements [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md), [NIP-13](https://github.com/nostr-protocol/nips/blob/master/13.md),  [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md)

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

Remove an existing subscription:

```dart
nostr.unsubscribe([subscription id]);
```

Remove a connected relay:

```dart
nostr.removeRelay([relay url]);
```
