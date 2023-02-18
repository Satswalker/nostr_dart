import 'dart:async';
import 'dart:developer';
import 'package:nostr_dart/src/relay_info.dart';

import 'subscription.dart';
import 'event.dart';
import 'relay.dart';

/// The relay pool.
///
/// This class is instantiated as a singleton by the `Nostr` class and provides
/// the interface for interacting with the client's connected relays.
class RelayPool {
  final Map<String, Relay> _relays = {};
  final Map<String, Subscription> _subscriptions = {};

  /// A list of relay urls currently in the relay pool.
  List<String> get list => _relays.keys.toList();

  /// A list of subscription IDs of existing subscriptions
  List<String> get subscriptions => _subscriptions.keys.toList();

  /// A map of relay information documents using relay URL as the key.
  Map<String, RelayInfo> get info =>
      _relays.map((key, value) => MapEntry(key, value.info));

  /// A map of relay connection status using relay URL as the key.
  Map<String, bool> get isConnected =>
      _relays.map((key, value) => MapEntry(key, value.isConnected));

  /// Connects to a relay and adds it to the relay pool.
  ///
  /// [relay] is a `Relay` object representing the relay to be added.
  /// Relays must support [NIP-15: End of Stored Events Notice](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20: Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)
  /// and will be rejected if they don't support these protocol features.
  /// [autoSubscribe] specifies if existing event subscriptions should be
  /// automatically requested from the newly added relay. The default behaviour
  /// is to not request automatically.
  ///
  /// Returns `true` if [relay] was added successfully or it was already
  /// present in the relay pool. Returns `false` if [relay] could not be added.
  Future<bool> add(Relay relay, {bool autoSubscribe = false}) async {
    if (_relays.containsKey(relay.url)) {
      return true;
    }

    relay.onError = (url) {
      log('Could not send or reconnect to relay $url');
      remove(url);
    };

    relay.listen(_onEvent);

    if (await relay.connect()) {
      _relays[relay.url] = relay;
      if (autoSubscribe) {
        for (Subscription subscription in _subscriptions.values) {
          relay.send(subscription.toJson());
        }
      }
      return true;
    }
    return false;
  }

  /// Removes [url] from the relay pool if it's in the pool.
  void remove(String url) {
    log('Removing $url');
    _relays[url]?.disconnect();
    _relays.remove(url);
  }

  /// Sends [jsonMessage] to all relays in the pool.
  ///
  /// Note that if an error occurs when [jsonMessage] is sent to an individual
  /// relay, for example if a timeout occurs, then the failing relay will be
  /// automatically removed from the pool.
  Future<void> send(List<dynamic> message) async {
    List<Future<void>> futures = [];

    for (Relay relay in _relays.values) {
      if (message[0] == "EVENT") {
        if (relay.access == WriteAccess.readOnly) {
          continue;
        }
      }
      if (message[0] == "REQ" || message[0] == "CLOSE") {
        if (relay.access == WriteAccess.writeOnly) {
          continue;
        }
      }
      try {
        futures.add(relay.send(message));
      } catch (err) {
        log(err.toString());
        remove(relay.url);
      }
    }
    await Future.wait(futures);
  }

  /// Requests events and subscribes to updates.
  ///
  /// [filters] is a list of Nostr subscription filters that determine what
  /// events will be returned by the connected relays. Each item in the list is
  /// an individual "filter" JSON object as defined by [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md).
  /// [onEvent] is a callback that will be invoked when Events are received from
  /// relays associated with this subscription request. Identical events
  /// from separate relays are treated independently meaning this callback
  /// may be invoked multiple times for the same event. This is so the client
  /// can determine from which relays any given event has been found.
  /// [id] is the subscription ID to identify the subscription request. If [id]
  /// not provided the subscription ID will be assigned a random 8-byte
  /// hexadecimal string.
  ///
  /// Note that the transmission of the subscription request to connected relays
  /// occurs asynchronously. nostr_dart maintains a message queue for each relay
  /// so that messages will be sent one at a time only after the previous
  /// message has acknowledged by the relay or a timeout occurs. This requires
  /// relays used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The returned [Future<String>] returns the subscription ID when the future
  /// completes. This future is completed when all relays that the subscription
  /// was sent to have either returned an end-of-stored events notice or thrown
  /// an error.
  ///
  /// An [ArgumentError] is thrown if [filters] is an empty list.
  ///
  /// Example:
  /// ```dart
  /// final subId = await nostr.subscribe([{
  ///  "ids": ["91cf9..4e5ca"]
  /// }]);
  /// ```
  Future<String> subscribe(
      List<Map<String, dynamic>> filters, Function(Event) onEvent,
      [String? id]) async {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    final Subscription subscription = Subscription(filters, onEvent, id);
    _subscriptions[subscription.id] = subscription;
    await send(subscription.toJson());
    return subscription.id;
  }

  /// Stops a previous subscription specified by [id].
  void unsubscribe(String id) {
    final subscription = _subscriptions.remove(id);
    if (subscription != null) {
      send(["CLOSE", subscription.id]);
    }
  }

  void _onEvent(List<dynamic> json) {
    final messageType = json[0];
    if (messageType == 'EVENT') {
      try {
        final event = Event.fromJson(json[2]);
        event.source = json[3] ?? '';
        final subId = json[1] as String;
        final subscriber = _subscriptions[subId];
        subscriber?.onEvent(event);
      } catch (err) {
        // OK to swallow these exceptions. They are only event data validation
        // or signature verification failures. Invalid events are ignored.
        log(err.toString());
      }
    }
  }
}
