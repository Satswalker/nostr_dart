import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import './relay.dart';
import './event.dart';
import './subscription.dart';
import './keys.dart';
import './command_result.dart';

class Nostr {
  Nostr._({privateKey = '', publicKey = '', powDifficulty = 0})
      : _privateKey = privateKey,
        _publicKey = publicKey,
        _powDifficulty = powDifficulty;

  final Map<String, Relay> _relays = {};
  final Map<String, Subscription> _subscriptions = {};
  final Set<Event> events = {};
  String _privateKey;
  String _publicKey;
  int _powDifficulty;
  final Queue<Completer<CommandResult>> _pendingCommandResults = Queue();
  final Queue<Completer<String>> _pendingSubscriptionResponses = Queue();

  set privateKey(String key) {
    if (!keyIsValid(key)) {
      throw ArgumentError('Invalid key format', 'key');
    } else {
      _publicKey = getPublicKey(key);
      _privateKey = key;
    }
  }

  String get privateKey => _privateKey;

  factory Nostr.init({String privateKey = '', int powDifficulty = 0}) {
    String publicKey = '';
    if (keyIsValid(privateKey)) {
      publicKey = getPublicKey(privateKey);
    }
    return Nostr._(
        privateKey: privateKey,
        publicKey: publicKey,
        powDifficulty: powDifficulty);
  }

  int relayCount() => _relays.length;

  bool hasRelay(String url) => _relays.containsKey(url);

  int eventCount() => events.length;

  bool hasSubscription(String id) => _subscriptions.containsKey(id);

  int subscriptionCount() => _subscriptions.length;

  Map<String, dynamic> getSubscription(String id) {
    Map<String, dynamic> subscription = {};
    if (_subscriptions.containsKey(id)) {
      subscription = _subscriptions[id]!.filters;
    }
    return subscription;
  }

  Future<void> addRelay(String url) async {
    final relay = Relay.init(url);

    relay.listen((relayMessage) {
      _parseRelayMessage(relayMessage);
    });

    await relay.connect();
    _relays[url] = relay;

    for (Subscription subscription in _subscriptions.values) {
      relay.subscribe(subscription);
    }
  }

  void removeRelay(String url) {
    if (_relays.containsKey(url)) {
      final Relay relay = _relays[url] as Relay;
      relay.disconnect();
      _relays.remove(url);
    } else {
      throw ArgumentError('$url is not a known relay', 'url');
    }
  }

  Future<CommandResult> sendTextNote(String textNote,
      [List<dynamic> tags = const []]) {
    if (_privateKey.isEmpty) {
      throw StateError("Private key is missing. Message can't be signed.");
    } else {
      Event event =
          Event.compose(_publicKey, EventKind.textNote, tags, textNote);
      event.doProofOfWork(_powDifficulty);
      event.sign(_privateKey);
      return _sendEvent(event);
    }
  }

  Future<CommandResult> setMetaData(
      {String name = '', String about = '', String picture = ''}) {
    Map<String, String> metaData = {};
    if (name != '') {
      metaData['name'] = name;
    }
    if (about != '') {
      metaData['about'] = about;
    }
    if (picture != '') {
      metaData['picture'] = picture;
    }
    if (_privateKey.isEmpty) {
      throw StateError("Private key is missing. Message can't be signed.");
    } else if (metaData.isEmpty) {
      throw ArgumentError("No metadata provided");
    } else {
      final jsonMetaData = jsonEncode(metaData);
      final event =
          Event.compose(_publicKey, EventKind.setMetaData, [], jsonMetaData);
      return _sendEvent(event);
    }
  }

  Future<CommandResult> recommendServer(String url) {
    if (_privateKey.isEmpty) {
      throw StateError("Private key is missing. Message can't be signed.");
    } else {
      if (!url.contains(RegExp(
          r'^(wss?:\/\/)([0-9]{1,3}(?:\.[0-9]{1,3}){3}|[^:]+):?([0-9]{1,5})?$'))) {
        throw ArgumentError('Not a valid websocket address', 'url');
      } else if (url.endsWith('.onion')) {
        throw ArgumentError('Tor addresses are not supported', 'url');
      } else {
        final event =
            Event.compose(_publicKey, EventKind.recommendServer, [], url);
        return _sendEvent(event);
      }
    }
  }

  Future<String> subscribe(Map<String, dynamic> filters,
      [String subscriptionId = '']) {
    final Subscription subscription;
    if (subscriptionId.isEmpty) {
      subscription = Subscription.init(filters);
    } else {
      subscription = Subscription.init(filters, id: subscriptionId);
    }
    _subscriptions[subscription.id] = subscription;
    final completer = Completer<String>();
    _pendingSubscriptionResponses.add(completer);
    for (Relay relay in _relays.values) {
      relay.subscribe(subscription);
    }
    return completer.future;
  }

  void unsubscribe(String subscriptionId) {
    if (_subscriptions.containsKey(subscriptionId)) {
      for (Relay relay in _relays.values) {
        relay.unsubscribe(subscriptionId);
      }
      _subscriptions.remove(subscriptionId);
    } else {
      throw ArgumentError(
          '$subscriptionId is not an existing subscription', 'subscriptionId');
    }
  }

  Future<CommandResult> _sendEvent(Event event) {
    event.doProofOfWork(_powDifficulty);
    event.sign(_privateKey);
    final completer = Completer<CommandResult>();
    completer.future.timeout(
      Duration(seconds: 5),
      onTimeout: () {
        throw ("Timeout awaiting response from relay");
      },
    );
    _pendingCommandResults.add(completer);
    for (Relay relay in _relays.values) {
      // TODO: Only post send to relays that have a write property
      relay.post(event);
    }
    return completer.future;
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
          final commandResult = CommandResult.parse(json);
          _pendingCommandResults.removeFirst().complete(commandResult);
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
