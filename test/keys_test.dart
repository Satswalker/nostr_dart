import 'package:nostr/src/keys.dart';
import 'package:test/test.dart';
import 'package:string_validator/string_validator.dart' as hex_string;
import '../test/constants.dart';

void main() {
  group('generatePrivateKey:', () {
    test('returns a 32-byte hex-encoded string', () {
      final String privateKey = generatePrivateKey();
      expect(privateKey.length, equals(64));
      expect(hex_string.isHexadecimal(privateKey), isTrue);
    });

    test("returns a different key each time it's called", () {
      List<String> keys = [];

      for (var i = 0; i < 100; i++) {
        String thisKey = generatePrivateKey();
        expect(keys, isNot(contains(thisKey)));
        keys.add(thisKey);
      }
    });
  });

  group('getPublicKey:', () {
    test('returns the public key of the given private key', () {
      expect(getPublicKey(TestConstants.privateKey),
          equals(TestConstants.publicKey));
    });

    test('raises an exception if the private key parameter is invalid', () {
      // Private key isn't a hexadecimal string
      expect(() => getPublicKey(TestConstants.keyNotHex), throwsArgumentError);

      // Private key isn't the correct length
      expect(() => getPublicKey(TestConstants.keyWrongLength),
          throwsArgumentError);
    });
  });
}
