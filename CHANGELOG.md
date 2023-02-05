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
