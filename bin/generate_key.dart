
import 'package:gobot_backend/utils/utils.dart';

void main() {
  final key1 = generateRandomKeys();
  final key2 = generateRandomKeys();
  final otp = otpGenerator();


  final accessKey =
      key1.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  final refreshKey =
      key2.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();

  final keys = {
    "access_key": accessKey.toUpperCase(),
    "refresh_key": refreshKey.toUpperCase(),
  };

  keys.forEach(
    (key, value) => print("$key : $value \n\notp:$otp"),
  );
}
