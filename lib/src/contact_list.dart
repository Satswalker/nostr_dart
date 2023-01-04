import 'dart:collection';
import 'keys.dart';

class ContactList with IterableMixin<Contact> {
  ContactList({Map<String, Contact>? contacts}) : _contacts = contacts ?? {};

  final Map<String, Contact> _contacts;

  @override
  Iterator<Contact> get iterator {
    return ContactsIterator(_contacts.values);
  }

  factory ContactList.fromJson(List<dynamic> tags) {
    // TODO: tags data validation
    Map<String, Contact> contacts = {};
    for (List<String> tag in tags) {
      final contact =
          Contact.init(publicKey: tag[1], url: tag[2], petname: tag[3]);
      contacts[contact.publicKey] = contact;
    }
    return ContactList(contacts: contacts);
  }

  List<dynamic> toJson() {
    List<dynamic> result = [];
    for (Contact contact in _contacts.values) {
      result.add(["p", contact.publicKey, contact.url, contact.petname]);
    }
    return result;
  }

  void add(Contact contact) {
    _contacts[contact.publicKey] = contact;
  }

  Contact get(String publicKey) {
    if (!_contacts.containsKey(publicKey)) {
      throw ArgumentError("Unknown contact", "publicKey");
    }
    return _contacts[publicKey] as Contact;
  }

  Contact remove(String publicKey) {
    if (!_contacts.containsKey(publicKey)) {
      throw ArgumentError("Unknown contact", "publicKey");
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

class Contact {
  Contact._(
      {required this.publicKey, required this.url, required this.petname});

  final String publicKey;
  String url;
  String petname;

  factory Contact.init(
      {required String publicKey, String url = '', String petname = ''}) {
    if (!keyIsValid(publicKey)) {
      throw ArgumentError("Key is invalid", "publicKey");
    }
    if (url.isNotEmpty &&
        !url.contains(RegExp(
            r'^(wss?:\/\/)([0-9]{1,3}(?:\.[0-9]{1,3}){3}|[^:]+):?([0-9]{1,5})?$'))) {
      throw ArgumentError('Not a valid websocket address', 'url');
    }
    return Contact._(publicKey: publicKey, url: url, petname: petname);
  }
}
