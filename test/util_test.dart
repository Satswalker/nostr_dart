import 'package:test/test.dart';
import 'package:nostr/src/util.dart';
import 'package:string_validator/string_validator.dart' as string;

void main() {
  group('getRandomHexString:', () {
    test('returns a 32-byte hexadecimal as a string by default', () {
      final result = getRandomHexString();

      expect(string.isHexadecimal(result), isTrue);
      expect(result.length, equals(64));
    });

    test('returns a different hexadecimal each time it is called', () {
      final List<String> buffer = [];

      for (var i = 0; i < 100; i++) {
        String randomString = getRandomHexString();
        expect(buffer, isNot(contains(randomString)));
        buffer.add(randomString);
      }
    });

    test('length of returned hexadecimal can be specified', () {
      String result = getRandomHexString(3);
      expect(result.length, equals(6));
      result = getRandomHexString(64);
      expect(result.length, equals(128));
    });

    test('raises an exception if "byteLength" is negative', () {
      expect(() => getRandomHexString(-1), throwsArgumentError);
    });
  });
}
