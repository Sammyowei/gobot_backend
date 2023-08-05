// import 'dart:convert';

import 'package:gobot_backend/utils/utils.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class UserApi {
  final DbCollection store;
  UserApi({required this.store});

  Handler get router {
    final router = Router();

    router.get("/", getUser);

    final handler =
        Pipeline().addMiddleware(checkAuthorization()).addHandler(router);

    return handler;
  }

  getUser(Request req) async {
    // final payload = await req.readAsString();
    // final jsonData = json.decode(payload);
    // final userName = jsonData["user_name"];
    // final email = jsonData["email_address"];
  }
}
