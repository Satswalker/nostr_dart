// Need to decide header
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:clock/clock.dart';
import 'package:bip340/bip340.dart' as schnorr;
import 'package:hex/hex.dart';
import 'package:string_validator/string_validator.dart';
import './keys.dart';
import './util.dart';

class Event {
  Event._(
      {required this.id,
      required this.pubkey,
      required this.createdAt,
      required this.kind,
      required this.content,
      required this.tags,
      this.sig = ''});

  String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  List<dynamic> tags;
  final String content;
  String sig;

  factory Event.fromJson(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final pubkey = data['pubkey'] as String;
    final createdAt = data['created_at'] as int;
    final kind = data['kind'] as int;
    final tags = data['tags'];
    final content = data['content'] as String;
    final sig = data['sig'] as String;

    _validate(id, pubkey, createdAt, kind, tags, content);
    _verifySignature(id, pubkey, sig);

    return Event._(
        id: id,
        pubkey: pubkey,
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content,
        sig: sig);
  }
  factory Event.compose(
      String publicKey, int kind, List<dynamic> tags, String content) {
    if (!keyIsValid(publicKey)) {
      throw ArgumentError("Invalid key: '$publicKey'", 'publicKey');
    }
    final int createdAt = _secondsSinceEpoch();
    final String id = _getId(publicKey, createdAt, kind, tags, content);

    return Event._(
        id: id,
        pubkey: publicKey,
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': sig
    };
  }

  void doProofOfWork(int difficulty) {
    const int nonceIndex = 1;
    if (difficulty < 0) {
      throw ArgumentError("PoW difficulty can't be negative", 'difficulty');
    } else if (difficulty > 0) {
      final difficultyInBytes = (difficulty / 8).ceil();
      List<dynamic> result = [];
      for (List<dynamic> tag in tags) {
        result.add(tag);
      }
      result.add(["nonce", "0", difficulty.toString()]);
      tags = result;
      int nonce = 0;
      do {
        tags.last[nonceIndex] = (++nonce).toString();
        id = _getId(pubkey, createdAt, kind, tags, content);
      } while (_countLeadingZeroBytes(id) < difficultyInBytes);
    }
  }

  void sign(String privateKey) {
    if (keyIsValid(privateKey)) {
      final aux = getRandomHexString();
      sig = schnorr.sign(privateKey, id, aux);
    }
  }

  // Individual events with the same "id" are equivalent
  @override
  bool operator ==(other) => other is Event && id == other.id;
  @override
  int get hashCode => id.hashCode;

  static int _secondsSinceEpoch() {
    final now = clock.now();
    final secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000;
    return secondsSinceEpoch;
  }

  static String _getId(String publicKey, int createdAt, int kind,
      List<dynamic> tags, String content) {
    final jsonData =
        json.encode([0, publicKey, createdAt, kind, tags, content]);
    final bytes = utf8.encode(jsonData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String _sign(String id, String privateKey) {
    final String aux = getRandomHexString();
    return schnorr.sign(privateKey, id, aux);
  }

  static void _validate(id, publicKey, createdAt, kind, tags, content) {
    if (!isHexadecimal(id) || id.length != 64) {
      throw ArgumentError('"id" is invalid', 'Event.fromJson');
    }
    final expectedId = _getId(publicKey, createdAt, kind, tags, content);
    if (id != expectedId) {
      throw ArgumentError('Event payload failed checksum', 'Event.fromJson');
    }
  }

  static void _verifySignature(id, publicKey, signature) {
    if (!schnorr.verify(publicKey, id, signature)) {
      throw ArgumentError(
          'Event signature failed verification', 'Event.fromJson');
    }
  }

  int _countLeadingZeroBytes(String eventId) {
    List<int> bytes = HEX.decode(eventId);
    int zeros = 0;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        zeros = (i + 1);
      } else {
        break;
      }
    }
    return zeros;
  }
}

class EventKind {
  static int get setMetaData => 0;
  static int get textNote => 1;
  static int get recommendServer => 2;
}
