import 'package:nostr_dart/src/model/subscription.dart';
import 'package:test/test.dart';
import 'package:string_validator/string_validator.dart' as hex_string;

void main() {
  group('Subscription():', () {
    test('Subscription ID is an 8-byte hexadecimal string', () {
      final sub = Subscription([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      expect(sub.id.length, equals(16));
      expect(hex_string.isHexadecimal(sub.id), isTrue);
    });

    test('Subscription ID is randomly generated', () {
      final sub1 = Subscription([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      final sub2 = Subscription([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      expect(sub1.id, isNot(equals(sub2.id)));
    });

    test('Subscription stores the filters parameter', () {
      final sub = Subscription([
        {
          "ids": [
            "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
          ]
        }
      ], (event) {});
      final List<Map<String, dynamic>> filters = sub.filters;
      expect(
          filters[0]['ids'][0],
          equals(
              "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"));
    });
  });
}
