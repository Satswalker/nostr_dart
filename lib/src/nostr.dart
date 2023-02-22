import 'dart:convert';
import 'dart:async';
import 'event.dart';
import 'keys.dart';
import 'contact_list.dart';
import 'relay_pool.dart';

/// The base class for a Nostr client.
class Nostr {
  String _privateKey;
  String _publicKey = '';
  final int powDifficulty;
  final pool = RelayPool();
  final bool disableSignatureVerification;

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
  /// [disableSignatureVerification] disables signature verification of received
  /// events when set to `true`. WARNING: By enabling this setting you will have
  /// no proof that received events have been created by who they say they are.
  /// This option is a temporary work-around until performance of signature
  /// verification is improved. By default signature verification is performed.
  /// If signature verification is disabled you can still verify the signature
  /// of individual events on a case-by-case basis with `Event.isValid`.
  ///
  /// Example:
  /// ```dart
  /// final nostr = Nostr(privateKey: "91cf9..4e5ca", powDifficulty: 16);
  /// ```
  Nostr(
      {String privateKey = '',
      this.powDifficulty = 0,
      this.disableSignatureVerification = false})
      : _privateKey = privateKey {
    _publicKey = privateKey.isNotEmpty ? getPublicKey(privateKey) : '';
  }

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

  /// Publishes a text_note event.
  ///
  /// [text] is the text that will form the content of the published event.
  /// [tags] is a JSON object of event tags to be included with the text note.
  ///
  /// Note that the transmission of the event to connected relays occurs
  /// asynchronously. nostr_dart maintains a message queue for each relay so
  /// that messages will be sent one at a time only after the previous message
  /// has acknowledged by the relay or a timeout occurs. This requires relays
  /// used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [Event] returned is the Nostr event that was published.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set.
  ///
  /// Example:
  /// ```dart
  /// final event = nostr.sendTextNote("Hello Nostr!", [
  ///   ["e", "91cf9..4e5ca"],["p", "612ae..e610f"]
  /// ]);
  /// ```
  Event sendTextNote(String text, [List<dynamic> tags = const []]) {
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
  /// Note that the transmission of the event to connected relays occurs
  /// asynchronously. nostr_dart maintains a message queue for each relay so
  /// that messages will be sent one at a time only after the previous message
  /// has acknowledged by the relay or a timeout occurs. This requires relays
  /// used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [Event] returned is the Nostr event that was published.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set or if none
  /// of the named parameters have been provided.
  ///
  /// Example:
  /// ```dart
  /// var event = nostr.sendMetaData(name: "Bob");
  /// ```
  Event sendMetaData({String? name, String? about, String? picture}) {
    Map<String, String> params = {};
    ({'name': name, 'about': about, 'picture': picture}).forEach((key, value) {
      if (value != null) params[key] = value;
    });

    if (params.isEmpty) throw ArgumentError("No metadata provided");

    final metaData = jsonEncode(params);
    final event = Event(_publicKey, EventKind.metaData, [], metaData);
    return sendEvent(event);
  }

  /// Publishes a recommend_server event.
  ///
  /// [url] is the URL of the relay being recommended.
  ///
  /// Note that the transmission of the event to connected relays occurs
  /// asynchronously. nostr_dart maintains a message queue for each relay so
  /// that messages will be sent one at a time only after the previous message
  /// has acknowledged by the relay or a timeout occurs. This requires relays
  /// used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [Event] returned is the Nostr event that was published.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set or if
  /// [url] is not a valid relay URL.
  ///
  /// Example:
  /// ```dart
  /// var event = nostr.recommendServer('wss://example.com');
  /// ```
  Event recommendServer(String url) {
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
  /// Note that the transmission of the event to connected relays occurs
  /// asynchronously. nostr_dart maintains a message queue for each relay so
  /// that messages will be sent one at a time only after the previous message
  /// has acknowledged by the relay or a timeout occurs. This requires relays
  /// used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [Event] returned is the Nostr event that was published.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set.
  /// A [TimeoutException] is thrown if no Command Response is received.
  ///
  /// Example:
  /// ```dart
  /// final contacts = ContactList();
  /// final anne = Contact(publicKey: "91cf9..4e5ca", petname: "anne");
  /// contacts.add(anne);
  /// var event = nostr.sendContactList(contacts);
  /// ```
  Event sendContactList(ContactList contacts) {
    final tags = contacts.toJson();
    final event = Event(_publicKey, EventKind.contactList, tags, "");
    return sendEvent(event);
  }

  /// Publishes an arbitrary event.
  ///
  /// Allows a custom [Event] to be composed and sent to connected relays.
  ///
  /// Note that the transmission of the event to connected relays occurs
  /// asynchronously. nostr_dart maintains a message queue for each relay so
  /// that messages will be sent one at a time only after the previous message
  /// has acknowledged by the relay or a timeout occurs. This requires relays
  /// used to support [NIP-15](https://github.com/nostr-protocol/nips/blob/master/15.md) and [NIP-20](https://github.com/nostr-protocol/nips/blob/master/20.md).
  ///
  /// The [Event] returned is the Nostr event that was published.
  ///
  /// An [ArgumentError] is thrown if the private key hasn't been set.
  ///
  /// Example:
  /// ```dart
  /// final event = Event(
  ///   "91cf9..4e5ca", 1, [], "A beautifully handcrafted event");
  /// var event = nostr.sendEvent(event);
  /// ```
  Event sendEvent(Event event) {
    if (_privateKey.isEmpty) {
      throw StateError("Private key is missing. Message can't be signed.");
    }
    event.doProofOfWork(powDifficulty);
    event.sign(_privateKey);
    pool.send(["EVENT", event.toJson()]);
    return event;
  }
}
