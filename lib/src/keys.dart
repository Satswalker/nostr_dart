import 'package:bip340/bip340.dart' as schnorr;
import 'package:string_validator/string_validator.dart';
import 'util.dart';

String generatePrivateKey() => getRandomHexString();

String getPublicKey(String privateKey) {
  if (!keyIsValid(privateKey)) {
    throw ArgumentError('Invalid key', 'privateKey');
  }
  return schnorr.getPublicKey(privateKey);
}

bool keyIsValid(String key) {
  return (isHexadecimal(key) && key.length == 64);
}
