import 'dart:convert';
import 'dart:io';

import 'package:gobot_backend/utils/utils.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class AuthApi {
  final DbCollection store;
  final DbCollection userStore;
  final String secret;

  AuthApi({
    required this.store,
    required this.secret,
    required this.userStore,
  });

  Router get router {
    final router = Router()
      ..post("/register", registerUser)
      ..post("/login", loginUser);

    return router;
  }

  // TODO: register user endpoint
  registerUser(Request req) async {
    final payload = await req.readAsString();
    final userInfo = json.decode(payload);
    final userName = userInfo["user_name"];
    final password = userInfo["password"];
    final email = userInfo["email_address"];

    if (userName == null || password == null || email == null) {
      return Response.badRequest(
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_name": userName ?? "require this field",
          "password": password ?? "required this field",
          "email_address": email ?? "require this field",
        }),
      );
    } else {
      var validEmail = email.toString().contains(
          RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'));
      var validPassword = password.toString().length >= 8;

      if (!validEmail || !validPassword) {
        var response = {
          "error": {
            "email_address": "please use a valid email address",
            "password": "password should be Longer than 8 characters",
          }
        };
        if (validEmail == true) {
          response["error"]!.remove("email_address");
        }
        if (validPassword == true) {
          response["error"]!.remove("password");
        }
        return Response.badRequest(
          headers: {"Content-Type": "application/json"},
          body: json.encode(response),
        );
      }
    }
// TODO: check if User is Unique

    var userEmail = await store.findOne(
      where.eq("email_address", email),
    );
    var username = await store.findOne(
      where.eq("user_name", userName),
    );

    final emailNotNull = userEmail != null;
    final userNameNotNull = username != null;
    print({
      "email_found": emailNotNull,
      "user_found": userNameNotNull,
    });
    var response = {
      "error": {
        "email_address": "a user already exist with this email address",
        "user_name": "a user already exist with this user name",
      }
    };

    if (emailNotNull == false) {
      response["error"]!.remove("email_address");
    }
    if (userNameNotNull == false) {
      response["error"]!.remove("user_name");
    }
    if (emailNotNull || userNameNotNull) {
      return Response.badRequest(
        body: json.encode(response),
      );
    } else {
      final salt = genrateSalt();
      final hashedPassword = hashPassword(password, salt);
      await store.insertOne({
        "email_address": email,
        "user_name": userName,
        "password": hashedPassword,
        "salt": salt,
        "is_disabled": false,
        "is_ristricted": false,
      });

      addRegisteredUser(userStore, email: email, userName: userName);
      return Response.ok(
          json.encode({
            "message": "sucessfully registered User with ${{
              "email_address": email,
              "user_name": userName,
              "password": hashedPassword,
              "salt": salt,
              "is_disabled": false,
              "is_ristricted": false,
            }}"
          }),
          headers: {"Content-Type": "applilcation/json"});
    }
  }

//TODO: login user endpoint
  loginUser(Request req) async {
    final payload = await req.readAsString();
    final userInfo = json.decode(payload);
    final emailOrUser = userInfo["email_or_username"];
    final password = userInfo["password"];

    if (emailOrUser == null || password == null) {
      var response = {
        "error": {
          "message": {
            "email_or_username": "require this field.",
            "password": "require this field."
          }
        }
      };
      if (emailOrUser != null) {
        response["error"]?["message"]?.remove("email_or_username");
      }
      if (password != null) {
        response["error"]?["message"]?.remove("password");
      }

      return Response.forbidden(json.encode(response),
          headers: {"Content-Type": "application/json"});
    } else {
      if (emailOrUser is! String) {
        var response = {
          "error": {
            "message": {"email_or_username": "invalid data type"}
          }
        };
        return Response.badRequest(body: json.encode(response), headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType
        });
      }
      final userEmail = await store.findOne(
        where.eq("email_address", emailOrUser),
      );
      final userName = await store.findOne(
        where.eq("user_name", emailOrUser),
      );

      var emailAvailable = userEmail != null;
      var userNameAvailable = userName != null;
      print("${{
        "email": emailAvailable,
        "username": userNameAvailable,
      }}");
      final user = userEmail ?? userName;

      if (user == null) {
        return Response.badRequest(
            body: json.encode(
              {
                "error": {"message": "this user does not exist"}
              },
            ),
            headers: {"Content-Type": "application/json"});
      }
      final hashedPassword = hashPassword(password, user["salt"]);
      if (hashedPassword != user["password"]) {
        return Response.forbidden(
          json.encode(
            {
              "error": {
                "message": "incorrect password",
              }
            },
          ),
          headers: {"Content-Type": "application/json"},
        );
      } else {
        final userID = (user["_id"] as ObjectId).toHexString();
        final token = generateJWT(userID, "http://localhost", secret);
        return Response.ok(
          json.encode(
            {
              "message": "user logged in sucessfully",
              "details": {
                "token": token,
              }
            },
          ),
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
        );
      }
    }
  }
}

// TODO: ForgotPassword
forgotPassword() async {}

void addRegisteredUser(DbCollection store,
    {required String email, required String userName}) async {
  final date = DateTime.now();

  final day = "${date.day}-${date.month}-${date.year}";
  final time = "${date.hour}:${date.minute}:${date.second}";

  await store.insertOne({
    "email": email,
    "user_name": userName,
    "created_at": "$day at $time",
    "updated_at": "$day  at $time",
    "is_subscribed": false,
    "bot_points": 10,
    "chat_history": <List<Map<String, String>>>[]
  });
}
