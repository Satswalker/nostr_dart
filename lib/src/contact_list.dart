import 'dart:collection';
import 'keys.dart';

/// A single contact for use with [ContactList]
class Contact {
  /// Creates a new [Contact].
  ///
  /// [publicKey] is a public key to identify the contact.
  /// [url] is a relay URL where events from [publicKey] can be found.
  /// [petname] is a local name (nickname) for the profile.
  ///
  /// An [ArgumentError] is thrown if [publicKey] is invalid or if [url] is not
  /// a valid relay URL.
  Contact({required this.publicKey, this.url = '', this.petname = ''}) {
    if (!keyIsValid(publicKey)) {
      throw ArgumentError.value(publicKey, 'publicKey', 'Invalid key');
    }
    if (url.isNotEmpty &&
        !url.contains(RegExp(
            r'^(wss?:\/\/)([0-9]{1,3}(?:\.[0-9]{1,3}){3}|[^:]+):?([0-9]{1,5})?$'))) {
      throw ArgumentError.value(url, 'url', 'Invalid relay address');
    }
  }

  /// The contact's public key.
  final String publicKey;

  /// A known good relay URL for the contact.
  final String url;

  /// The contact's petname (nickname).
  final String petname;
}

/// A contact list.
///
/// It can either be created as an empty contact list or populated using JSON
/// data from a NIP-02 `contact_list` event:
///
/// ```dart
/// // Create an empty contact list
/// var contacts = ContactList();
///
/// // Create a contact list populated by `contact_list` event tags
/// contacts = ContactList.fromJson([
///   ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"],
///   ["p", "14aeb..8dad4", "wss://bobrelay.com/nostr", "bob"],
///   ["p", "612ae..e610f", "ws://carolrelay.com/ws", "carol"]
/// ]);
/// ```
///
/// [ContactList] is iterable so in addition to [ContactList.get] contacts in
/// the contact list can be accessed like this:
///
/// ```dart
/// for (Contact c in contacts){
///   print(c.petname);
/// }
/// ```
class ContactList with IterableMixin<Contact> {
  /// Creates an empty [ContactList].
  ContactList() : _contacts = {};

  /// Creates a [ContactList] populated from [tags] which is a JSON array of
  /// event tags from a `contact_list` event as defined by [NIP-02](https://github.com/nostr-protocol/nips/blob/master/02.md).
  ///
  /// Example:
  /// ```dart
  /// final contacts = ContactList.fromJson([
  ///   ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"],
  ///   ["p", "14aeb..8dad4", "wss://bobrelay.com/nostr", "bob"],
  ///   ["p", "612ae..e610f", "ws://carolrelay.com/ws", "carol"]
  /// ]);
  /// ```
  factory ContactList.fromJson(List<dynamic> tags) {
    // TODO: tags data validation
    Map<String, Contact> contacts = {};
    for (List<String> tag in tags) {
      final contact = Contact(publicKey: tag[1], url: tag[2], petname: tag[3]);
      contacts[contact.publicKey] = contact;
    }
    return ContactList._(contacts);
  }

  ContactList._(Map<String, Contact> contacts) : _contacts = contacts;

  final Map<String, Contact> _contacts;

  @override
  Iterator<Contact> get iterator {
    return ContactsIterator(_contacts.values);
  }

  /// Returns the contact list as a JSON array of event tags.
  List<dynamic> toJson() {
    List<dynamic> result = [];
    for (Contact contact in _contacts.values) {
      result.add(["p", contact.publicKey, contact.url, contact.petname]);
    }
    return result;
  }

  /// Adds [contact] to the [ContactList].
  ///
  /// Can also be used to update existing contacts as entries for already known
  /// public keys will be overwritten.
  void add(Contact contact) {
    _contacts[contact.publicKey] = contact;
  }

  /// Gets a [Contact] specified by [publicKey].
  ///
  /// An [ArgumentError] is thrown if [publicKey] is unknown.
  Contact get(String publicKey) {
    if (!_contacts.containsKey(publicKey)) {
      throw ArgumentError.value(publicKey, 'publicKey', "Unknown contact");
    }
    return _contacts[publicKey] as Contact;
  }

  /// Removes a [Contact] specified by [publicKey] from the [ContactList] and
  /// returns the removed [Contact].
  ///
  /// An [ArgumentError] is thrown if [publicKey] is unknown.
  Contact remove(String publicKey) {
    if (!_contacts.containsKey(publicKey)) {
      throw ArgumentError.value(publicKey, 'publicKey', "Unknown contact");
    }
    return _contacts.remove(publicKey) as Contact;
  }
}

class ContactsIterator<Contact> implements Iterator<Contact> {
  final Iterable<Contact> _iterable;
  final int _length;
  int _index;
  Contact? _current;

  ContactsIterator(Iterable<Contact> iterable)
      : _iterable = iterable,
        _length = iterable.length,
        _index = 0;

  @override
  Contact get current => _current as Contact;

  @override
  bool moveNext() {
    int length = _iterable.length;
    if (_length != length) {
      throw ConcurrentModificationError(_length);
    }
    if (_index >= length) {
      _current = null;
      return false;
    }
    _current = _iterable.elementAt(_index);
    _index++;
    return true;
  }
}
