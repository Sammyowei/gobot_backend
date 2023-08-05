import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

String generateJWT(String subject, String issuer, String secret) {
  final jwt = JWT(
    {
      "iat": DateTime.now().millisecondsSinceEpoch,
    },
    subject: subject,
    issuer: issuer,
  );
  return jwt.sign(
    SecretKey(secret),
  );
}

dynamic verifyJWT(String token, String secret) {
  try {
    final jwt = JWT.verify(
      token,
      SecretKey(secret),
    );
    return jwt;
  } on JWTException catch (err) {
    return err.message;
  }
}
