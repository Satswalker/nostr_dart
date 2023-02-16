## 0.1.0

- Initial version.

## 0.1.1

- Fixed package import documentation.

## 0.2.0

- Added support for [NIP-02: Contact List and Petnames](https://github.com/nostr-protocol/nips/blob/master/02.md).

## 0.3.0

- Reworked `Contact` & `Nostr` class constructors to make instantiating these classes more terse.
- Added a method to publish arbitrary events [Nostr.sendEvent].

## 0.4.0

- Refactored relay management and subscription requests into a RelayPool class. This changes the interfaces for adding/removing relays and subscribing/unsubscribing to events.
- `Nostr.pool.add` only sends existing subscriptions to a newly added relay if its `autoSubscribe` parameter is `true`.
- `Nostr.pool.add` allows read/write attributes to be configured for relays with its `access` parameter.
- Received events are now accessed via a listener callback provided to `Nostr.pool.subscribe`. This allows different subscriptions to route events to different event listeners.
- `Nostr.sendTextNote`, `Nostr.sendMetaData`, `Nostr.recommendServer`, `Nostr.sendContactList`, `Nostr.pool.subscribe`, are no longer asynchronous operations. `nostr_dart` now maintains an asynchronous job queue for each connected relay to sequence relay communications.

## 0.4.1

- Fixed incorrectly formatted subscription requests.

## 0.5.0

- Shortened the length of randomly assigned Subscription IDs to an 8-byte hexadecimal string. Some relays were rejecting a 32-byte hexadecimal.
- `Nostr.pool.subscribe` is now an asynchronous operation returning a `Future` that completes when all expected end-of-stored events notices have been received.

## 0.6.0

- Added support for [NIP-11: Relay Information Document](https://github.com/nostr-protocol/nips/blob/master/11.md). This includes a breaking API change to `Nostr.pool.add` which now takes a `Relay` object instead of a URL `string` and `access` read/write configuration.
- Added `Nostr.pool.info` to get relay information documents. This interface is likely to change.
- Added an automatic check for NIP-15 and NIP-20 support before connecting to a relay. Relays that don't support these protocol features will be rejected.
- Added `Nostr.pool.isConnected` to get relay connection status. This interface is likely to change.

## 0.6.1

- Fixed subscription requests timing out prematurely.
