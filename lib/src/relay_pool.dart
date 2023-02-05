import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'model/subscription.dart';
import 'model/event.dart';
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

  /// Connects to the relay specified by [url].
  ///
  /// If the client has any existing subscriptions these will be requested
  /// automatically from the newly connected relay if [autoSubscribe] is `true`.
  ///
  /// [access] specifies read/write access for the added relay and may be set to
  /// either `WriteAccess.readOnly`, `WriteAccess.writeOnly`, or
  /// `WriteAccess.readWrite`. If not provided the default is read-only.
  ///
  /// NOTE: Relays must support [NIP-15: End of Stored Events Notice](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20: Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)
  /// In a future version `nostr_dart` will check that added relays support
  /// these NIPs but for now this check is unimplemented.
  ///
  /// Returns `true` if [url] was added successfully or it was already
  /// present. Returns `false` if [url] could not be added.
  ///
  /// A [WebSocketException] is thrown if [url] is not a valid relay URL.
  /// A [TimeoutException] is thrown if the connection attempt times out.
  Future<bool> add(String url,
      {bool autoSubscribe = false,
      WriteAccess access = WriteAccess.readOnly}) async {
    if (_relays.containsKey(url)) {
      return true;
    }

    final relay = Relay(url, access: access, onDone: (relay) {
      log('$url websocket stream closed');
      remove(url);
    });
    relay.listen(_onEvent);

    if (await relay.connect()) {
      _relays[url] = relay;
      if (autoSubscribe) {
        for (Subscription subscription in _subscriptions.values) {
          final message = jsonEncode(subscription.toJson());
          relay.send(message);
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
  void send(List<dynamic> jsonMessage) {
    for (Relay relay in _relays.values) {
      if (jsonMessage[0] == "EVENT") {
        if (relay.access == WriteAccess.readOnly) {
          continue;
        }
      }
      if (jsonMessage[0] == "REQ" || jsonMessage[0] == "CLOSE") {
        if (relay.access == WriteAccess.writeOnly) {
          continue;
        }
      }
      try {
        final message = jsonEncode(jsonMessage);
        relay.send(message);
      } catch (err) {
        log(err.toString());
        remove(relay.url);
      }
    }
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
  /// not provided the subscription ID will be assigned a random 32-byte
  /// hexadecimal string.
  ///
  /// Note that the transmission of the subscription request to connected relays
  /// occurs asynchronously. nostr_dart maintains a message queue for each relay
  /// so that messages will be sent one at a time only after the previous
  /// message has acknowledged by the relay or a timeout occurs. This requires
  /// relays used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [String] returned is the subscription's ID. This way, if [id] was not
  /// provided, the client can determine the randomly assigned subscription ID.
  ///
  /// An [ArgumentError] is thrown if [filters] is an empty list.
  ///
  /// Example:
  /// ```dart
  /// final subId = nostr.subscribe([{
  ///  "ids": ["91cf9..4e5ca"]
  /// }]);
  /// ```
  String subscribe(List<Map<String, dynamic>> filters, Function(Event) onEvent,
      [String? id]) {
    if (filters.isEmpty) {
      throw ArgumentError("No filters given", "filters");
    }

    final Subscription subscription = Subscription(filters, onEvent, id);
    _subscriptions[subscription.id] = subscription;
    send(subscription.toJson());
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
