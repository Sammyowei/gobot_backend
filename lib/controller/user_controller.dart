// import 'dart:convert';

import 'dart:convert';
import 'dart:io';

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

  static final headers = <String, String>{
    HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
  };

  getUser(Request req) async {
    // final payload = await req.readAsString();
    // final jsonData = json.decode(payload);
    // final id = jsonData["_id"];

    var response = <String, dynamic>{};

    // if (id == null) {
    //   response = {
    //     "error": {
    //       "_id": "the user ID is required",
    //     },
    //   };

    //   return Response.badRequest(body: json.encode(response), headers: headers);
    // }

    // final userId = ObjectId.fromHexString(id);
    // final query = where.eq("_id", userId);

    // final user = await store.findOne(query);

    // if (user == null) {
    //   response = {
    //     "error": {"message": "this user cannot be found in the database"}
    //   };
    //   return Response.notFound(json.encode(response), headers: headers);
    // }

    // response = user;

    return Response.ok(json.encode(response), headers: headers);
  }
}
