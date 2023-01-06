import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'relay.dart';
import 'event.dart';
import 'subscription.dart';
import 'keys.dart';
import 'contact_list.dart';

/// A command result returned in response to publishing an event.
class CommandResult {
  /// The raw command result message as a JSON array.
  final List<dynamic> _result;

  /// The ID of the event that the [CommandResult] refers to.
  final String id;

  /// Whether the event was successfully published.
  final bool success;

  /// Additional information as to why the command succeeded or failed.
  final String message;

  CommandResult(List<dynamic> result)
      : _result = result,
        id = result[1],
        success = result[2],
        message = result[3];

  @override

  /// Returns the raw command result message as a [String].
  String toString() {
    return _result.toString();
  }
}

/// The base class for a Nostr client.
class Nostr {
  /// Creates a Nostr client.
  ///
  /// [privateKey] is the user's secret key used for signing event messages and
  /// must be a 32-byte hexadecimal string otherwise it will be ignored. If it
  /// is not provided the client will be unable to publish events and attempts
  /// to do so will throw an exception. However, the secret key can be provided
  /// after client creation using [Nostr.privateKey].
  ///
  /// [powDifficulty] specifies the target of proof-of-work difficulty that will
  /// be performed before publishing events. If [powDifficulty] is not provided
  /// proof-of-work is not performed.
  ///
  /// Example:
  /// ```dart
  /// final nostr = Nostr(privateKey: "91cf9..4e5ca", powDifficulty: 16);
  /// ```
  Nostr({String privateKey = '', powDifficulty = 0})
      : _privateKey = privateKey,
        _powDifficulty = powDifficulty {
    _publicKey = privateKey.isNotEmpty ? getPublicKey(privateKey) : '';
  }

  String _privateKey;
  String _publicKey = '';
  final int _powDifficulty;
  final Map<String, Relay> _relays = {};
  final Map<String, Subscription> _subscriptions = {};
  final Queue<Completer<CommandResult>> _pendingCommandResults = Queue();
  final Queue<Completer<String>> _pendingSubscriptionResponses = Queue();

  /// Set containing any events received from connected relays.
  final Set<Event> events = {};

  /// Sets the secret key used for signing events.
  ///
  /// [key] must be a 32-byte hexadecimal string.
  ///
  /// An [ArgumentError] is thrown if [key] is invalid.
  set privateKey(String key) {
    if (!keyIsValid(key)) {
      throw ArgumentError.value(key, 'key', 'Invalid key');
    } else {
      _publicKey = getPublicKey(key);
      _privateKey = key;
    }
  }

  /// The secret key used for event signing.
  ///
  /// The value is an empty string if there is no secret key.
  String get privateKey => _privateKey;

  /// The number of relays in the relay pool.
  int get relayCount => _relays.length;

  /// Whether the relay pool contains [url].
  bool hasRelay(String url) => _relays.containsKey(url);

  /// Whether the client has a subscription identified as [id].
  bool hasSubscription(String id) => _subscriptions.containsKey(id);

  /// The number of existing subscriptions.
  int get subscriptionCount => _subscriptions.length;

  /// Returns the subscription filters for an existing subscription with an ID
  /// of [id].
  ///
  /// The subscription filters is JSON data returned as a Map. If [id] doesn't
  /// match any existing subscriptions then an empty Map is returned.
  Map<String, dynamic> getSubscription(String id) {
    Map<String, dynamic> subscription = {};
    if (_subscriptions.containsKey(id)) {
      subscription = _subscriptions[id]!.filters;
    }
    return subscription;
  }

  /// Connects to the relay specified by [url].
  ///
  /// If the client has any existing subscriptions these will be requested
  /// automatically from the newly connected relay.
  ///
  /// This is an asynchronous operation returning a `Future<void>` that
  /// completes after either successful relay connection or an exception is
  /// thrown.
  ///
  /// NOTE: Relays must support [NIP-20: Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)
  ///
  /// A [WebSocketException] is thrown if [url] is not a valid relay URL.
  /// A [TimeoutException] is thrown if the connection attempt times out.
  Future<void> addRelay(String url) async {
    final relay = Relay(url);

    relay.listen((relayMessage) {
      _parseRelayMessage(relayMessage);
    });

    await relay.connect();
    _relays[url] = relay;

    for (Subscription subscription in _subscriptions.values) {
      relay.subscribe(subscription);
    }
  }

  /// Disconnects the relay specified by [url] and removes it from the
  /// relay pool.
  ///
  /// An [ArgumentError] is thrown if [url] is not in the relay pool.
  void removeRelay(String url) {
    if (!_relays.containsKey(url)) {
      throw ArgumentError.value(url, 'url', 'Unknown relay');
    }
    _relays[url]!.disconnect();
    _relays.remove(url);
  }

  /// Publishes a text_note event.
  ///
  /// [text] is the text that will form the content of the published event.
  /// [tags] is a JSON object of event tags to be included with the text note.
  ///
  /// This is an asynchronous operation returning a `Future<CommandResult>` that
  /// completes after either a Command Result is received or an exception is
  /// thrown. This requires relays used to support [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [CommandResult] returned when the Future completes can be used to
  /// confirm the event was published successfully.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set.
  /// A [TimeoutException] is thrown if no Command Response is received.
  ///
  /// Example:
  /// ```dart
  /// final result = await nostr.sendTextNote("Hello Nostr!", [
  ///   ["e", "91cf9..4e5ca"],["p", "612ae..e610f"]
  /// ]);
  /// ```
  Future<CommandResult> sendTextNote(String text,
      [List<dynamic> tags = const []]) {
    Event event = Event(_publicKey, EventKind.textNote, tags, text);
    return sendEvent(event);
  }

  /// Publishes a set_metadata event.
  ///
  /// [name] is a name to be associated with the event's public
  /// key.
  /// [about] is a personal description to be associated with the event's
  /// public key.
  /// [picture] is a URL to a profile picture to be associated with the event's
  /// public key.
  ///
  /// This is an asynchronous operation returning a `Future<CommandResult>` that
  /// completes after either a Command Result is received or an exception is
  /// thrown. This requires relays used to support [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [CommandResult] returned when the Future completes can be used to
  /// confirm the event was published successfully.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set or if none
  /// of the named parameters have been provided.
  /// A [TimeoutException] is thrown if no Command Response is received.
  ///
  /// Example:
  /// ```dart
  /// var result = await nostr.setMetaData(name: "Bob");
  /// ```
  Future<CommandResult> setMetaData(
      {String? name, String? about, String? picture}) {
    Map<String, String> params = {};
    ({'name': name, 'about': about, 'picture': picture}).forEach((key, value) {
      if (value != null) params[key] = value;
    });

    if (params.isEmpty) throw ArgumentError("No metadata provided");

    final metaData = jsonEncode(params);
    final event = Event(_publicKey, EventKind.setMetaData, [], metaData);
    return sendEvent(event);
  }

  /// Publishes a recommend_server event.
  ///
  /// [url] is the URL of the relay being recommended.
  ///
  /// This is an asynchronous operation returning a `Future<CommandResult>` that
  /// completes after either a Command Result is received or an exception is
  /// thrown. This requires relays used to support [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [CommandResult] returned when the Future completes can be used to
  /// confirm the event was published successfully.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set or if
  /// [url] is not a valid relay URL.
  /// A [TimeoutException] is thrown if no Command Response is received.
  ///
  /// Example:
  /// ```dart
  /// var result = await nostr.recommendServer('wss://example.com');
  /// ```
  Future<CommandResult> recommendServer(String url) {
    if (!url.contains(RegExp(
        r'^(wss?:\/\/)([0-9]{1,3}(?:\.[0-9]{1,3}){3}|[^:]+):?([0-9]{1,5})?$'))) {
      throw ArgumentError.value(url, 'url', 'Not a valid relay URL');
    }
    final event = Event(_publicKey, EventKind.recommendServer, [], url);
    return sendEvent(event);
  }

  /// Publishes a contact_list event.
  ///
  /// [contacts] is the contact list to be published.
  ///
  /// This is an asynchronous operation returning a `Future<CommandResult>` that
  /// completes after either a Command Result is received or an exception is
  /// thrown. This requires relays used to support [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [CommandResult] returned when the Future completes can be used to
  /// confirm the event was published successfully.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set.
  /// A [TimeoutException] is thrown if no Command Response is received.
  ///
  /// Example:
  /// ```dart
  /// final contacts = ContactList();
  /// final anne = Contact(publicKey: "91cf9..4e5ca", petname: "anne");
  /// contacts.add(anne);
  /// var result = await nostr.sendContactList(contacts);
  /// ```
  Future<CommandResult> sendContactList(ContactList contacts) {
    final tags = contacts.toJson();
    final event = Event(_publicKey, EventKind.contactList, tags, "");
    return sendEvent(event);
  }

  /// Publishes an arbitrary event.
  ///
  /// Allows a custom [Event] to be composed and sent to connected relays.
  ///
  /// This is an asynchronous operation returning a `Future<CommandResult>` that
  /// completes after either a Command Result is received or an exception is
  /// thrown. This requires relays used to support [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [CommandResult] returned when the Future completes can be used to
  /// confirm the event was published successfully.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set.
  /// A [TimeoutException] is thrown if no Command Response is received.
  ///
  /// Example:
  /// ```dart
  /// final event = Event(
  ///   "91cf9..4e5ca", 1, [], "A beautifully handcrafted event");
  /// var result = await nostr.sendEvent(event);
  /// ```
  Future<CommandResult> sendEvent(Event event) {
    if (_privateKey.isEmpty) {
      throw StateError("Private key is missing. Message can't be signed.");
    }
    event.doProofOfWork(_powDifficulty);
    event.sign(_privateKey);
    final completer = Completer<CommandResult>();
    completer.future.timeout(
      Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException(
            "Command Response not received", Duration(seconds: 5));
      },
    );
    _pendingCommandResults.add(completer);
    for (Relay relay in _relays.values) {
      // TODO: Only post send to relays that have a write property
      relay.post(event);
    }
    return completer.future;
  }

  /// Requests events and subscribes to updates.
  ///
  /// [filters] is a JSON object that determines what events will be returned by
  /// the subscription, as defined by [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md).
  /// [id] is the subscription ID to be used in the subscription request. If
  /// not provided the subscription ID will be assigned a random 32-byte
  /// hexadecimal string.
  ///
  /// This is an asynchronous operation returning a `Future<String>` that
  /// completes after either an End-of-Stored Events message is received or an
  /// exception is thrown. This requires relays used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md).
  ///
  /// When `Future<String>` completes successfully it returns the assigned
  /// subscription ID.
  ///
  /// A [TimeoutException] is thrown if no End-of-Stored Events message is
  /// received.
  ///
  /// Example:
  /// ```dart
  /// final subId = await nostr.subscribe({
  ///  "ids": ["91cf9..4e5ca"]
  /// });
  /// ```
  Future<String> subscribe(Map<String, dynamic> filters, [String? id]) {
    final Subscription subscription = Subscription(filters, id);
    _subscriptions[subscription.id] = subscription;
    final completer = Completer<String>();
    completer.future.timeout(
      Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException(
            "EOSE message not received", Duration(seconds: 5));
      },
    );
    _pendingSubscriptionResponses.add(completer);
    for (Relay relay in _relays.values) {
      relay.subscribe(subscription);
    }
    return completer.future;
  }

  /// Stops a previous subscription specified by [id].
  ///
  /// An [ArgumentError] is thrown if [id] is not a known subscription ID.
  void unsubscribe(String id) {
    if (!_subscriptions.containsKey(id)) {
      throw ArgumentError.value(id, 'id', 'Unknown subscription ID');
    }
    for (Relay relay in _relays.values) {
      relay.unsubscribe(id);
    }
    _subscriptions.remove(id);
  }

  void _parseRelayMessage(String message) {
    final json = jsonDecode(message);
    final messageType = json[0];
    switch (messageType) {
      case 'EVENT':
        final subId = json[1];
        if (_subscriptions.containsKey(subId)) {
          final event = Event.fromJson(json[2]);
          events.add(event);
        }
        break;
      case 'OK':
        if (_pendingCommandResults.isNotEmpty) {
          final result = CommandResult(json);
          _pendingCommandResults.removeFirst().complete(result);
        }
        break;
      case 'EOSE':
        if (_pendingSubscriptionResponses.isNotEmpty) {
          final String subId = json[1];
          _pendingSubscriptionResponses.removeFirst().complete(subId);
        }
        break;
      case 'NOTICE':
        print(json);
        // TODO: Do something useful with relay notices
        break;
    }
  }
}
