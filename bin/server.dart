import 'dart:io';

import 'package:gobot_backend/config.dart';
import 'package:gobot_backend/controller/user_controller.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:gobot_backend/src.dart';

// Configure routes.

final router = AppRouter.router;

void main() async {

  bool prod = false;
  late Db db;
  try {
    db = prod == true?  await Db.create(Env.mongoUrl): Db("mongodb://localhost:27017/gobotdb");
    await db.open();
    print("connected sucessfully");
  } catch (error) {
    print(error);
  }

  final store = db.collection("user_auth");
  final userStore = db.collection("user_data");
  final secret = Env.accessToken;

  router.mount(
      "/auth/",
      AuthApi(
        store: store,
        secret: secret,
        userStore: userStore,
      ).router);
  router.mount("/user/", UserApi(store: userStore).router);
  final ip = InternetAddress.anyIPv4;

  final handler = Pipeline()
      .addMiddleware(
        handleAuth(secret),
      )
      .addMiddleware(
        logRequests(),
      )
      .addHandler(
        router,
      );

  final port = int.parse(Platform.environment['PORT'] ?? '3020');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
