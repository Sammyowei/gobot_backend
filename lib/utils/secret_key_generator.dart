import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Uint8List generateRandomKeys() {
  var random = Random.secure();
  var keyLength = 32;

  var randomBytes = List.generate(keyLength, (i) => random.nextInt(256));

  var sha = sha256;
  var hashedByte = sha.convert(Uint8List.fromList(randomBytes)).bytes;

  return Uint8List.fromList(hashedByte);
}
