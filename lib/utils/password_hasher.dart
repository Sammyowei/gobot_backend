import 'dart:convert';

import 'dart:math';

import 'package:crypto/crypto.dart';

String genrateSalt([int length = 32]) {
  final rand = Random.secure();
  final saltByte = List<int>.generate(length, (index) => rand.nextInt(256));
  return base64Encode(saltByte);
}

String hashPassword(String password, String salt) {
  final codec = Utf8Codec();
  final key = codec.encode(password);
  final saltByte = codec.encode(salt);
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(saltByte);
  return digest.toString();
}
