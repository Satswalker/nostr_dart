import 'package:bip340/bip340.dart' as schnorr;
import 'package:string_validator/string_validator.dart';
import 'util.dart';

/// Generates a random new secret key which is a 32-byte hexadecimal string.
String generatePrivateKey() => getRandomHexString();

/// Returns the BIP340 public key derived from [privateKey].
///
/// An [ArgumentError] is thrown if [privateKey] is invalid.
String getPublicKey(String privateKey) {
  if (!keyIsValid(privateKey)) {
    throw ArgumentError.value(privateKey, 'privateKey', 'Invalid key');
  }
  return schnorr.getPublicKey(privateKey);
}

/// Whether [key] is a a 32-byte hexadecimal string.
bool keyIsValid(String key) {
  return (isHexadecimal(key) && key.length == 64);
}
