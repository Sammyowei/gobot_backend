import 'package:envied/envied.dart';

part 'config.g.dart';

@Envied()
class Env {
  @EnviedField(varName: "MONGO_URL")
  static const String mongoUrl = _Env.mongoUrl;

  @EnviedField(varName: "SECRET_REFRESH_TOKEN")
  static const String refreshToken = _Env.refreshToken;

  @EnviedField(varName: "SECRET_ACCESS_TOKEN")
  static const String accessToken = _Env.accessToken;

  @EnviedField(varName: "SMPT_SERVER_USERNAME")
  static const String smptUsername = _Env.smptUserName;

  @EnviedField(varName: "SMPT_SERVER_PASSWORD")
  static const String smptPassword = _Env.smptPassword;
}
