import 'package:nostr_dart/src/subscription.dart';
import 'package:test/test.dart';
import 'package:string_validator/string_validator.dart' as hex_string;

void main() {
  group('Subscription():', () {
    test('Subscription ID is a 32-byte hexadecimal string', () {
      final sub = Subscription({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      expect(sub.id.length, equals(64));
      expect(hex_string.isHexadecimal(sub.id), isTrue);
    });

    test('Subscription ID is randomly generated', () {
      final sub1 = Subscription({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      final sub2 = Subscription({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      expect(sub1.id, isNot(equals(sub2.id)));
    });

    test('Subscription stores the filters parameter', () {
      final sub = Subscription({
        "ids": [
          "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"
        ]
      });
      final Map<String, dynamic> filters = sub.filters;
      expect(
          filters['ids'][0],
          equals(
              "88584637dd3434e0694165581455a6f9ec9010831a0cf1c2b65ae52c677dfea6"));
    });

    // test('raises an exception if filter is invalid', () {});

    // TODO: Test that duplicate subscriptions (by filters) can't be created.
    //       Will need to refactor subscriptions to use a hash of the filters
    //       as key instead of subId.
  });
}
