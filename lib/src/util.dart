import 'dart:math';
import 'package:hex/hex.dart';

String getRandomHexString([int byteLength = 32]) {
  final Random random = Random.secure();
  var bytes = List<int>.generate(byteLength, (i) => random.nextInt(256));
  return HEX.encode(bytes);
}
