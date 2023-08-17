import 'dart:convert';
import 'dart:io';

import 'package:gobot_backend/utils/utils.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class AuthApi {
  final DbCollection store;
  final DbCollection userStore;
  final String secret;

  static Map<String, String> headers = {
    HttpHeaders.contentTypeHeader: ContentType.json.mimeType
  };
  AuthApi({
    required this.store,
    required this.secret,
    required this.userStore,
  });

  Router get router {
    final router = Router()
      ..post("/register", registerUser)
      ..post("/login", loginUser)
      ..post("/forgotPassword", forgotPasswordRequest)
      ..post("/verifyOtp", verifyOtp)
      ..patch("/logout", logOut);
      

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
        "logged_in": false,
        "is_disabled": false,
        "is_ristricted": false,
        "otp": 660543
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
    final emailAddress = userInfo["email_address"];
    final password = userInfo["password"];

    if (emailAddress == null || password == null) {
      var response = {
        "error": {
          "message": {
            "email_address": "require this field.",
            "password": "require this field."
          }
        }
      };
      if (emailAddress != null) {
        response["error"]?["message"]?.remove("email_address");
      }
      if (password != null) {
        response["error"]?["message"]?.remove("password");
      }

      return Response.forbidden(json.encode(response),
          headers: {"Content-Type": "application/json"});
    } else {
      if (emailAddress is! String) {
        var response = {
          "error": {
            "message": {"email_address": "invalid data type"}
          }
        };
        return Response.badRequest(body: json.encode(response), headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType
        });
      }
      final authEmail = await store.findOne(
        where.eq("email_address", emailAddress),
      );

      var emailAvailable = authEmail != null;

      print("${{
        "email": emailAvailable,
      }}");
      var user = authEmail;

      if (user == null) {
        return Response.badRequest(
            body: json.encode(
              {
                "error": {"message": "user does not exist"}
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
        final getUserID = await userStore.findOne(
          where.eq("email", emailAddress),
        );

        print(getUserID?["_id"]);
        if (getUserID == null) {
          return Response.forbidden("404 error: not found");
        }

        final id = getUserID["_id"];
        print(id);
        final userID = (user["_id"] as ObjectId).toHexString();
        final token = generateJWT(userID, "http://localhost", secret);
        await store.updateOne(
          where.eq(
            "_id",
            ObjectId.fromHexString(userID),
          ),
          modify.set("logged_in", true),
        );
        return Response.ok(
          json.encode(
            {
              "message": "user logged in sucessfully",
              "details": {
                "token": token,
                "user_id": id,
              }
            },
          ),
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
        );
      }
    }
  }

// TODO: forgot Password
  forgotPasswordRequest(Request request) async {
    final payLoad = await request.readAsString();
    final jsonData = json.decode(payLoad);
    final email = jsonData["email_address"];

    if (email == null) {
      return Response.badRequest(
        body: json.encode(
          {
            "error": {
              "message": "require the email address",
            }
          },
        ),
      );
    }

    final query = where.eq("email_address", email);
    final field = ["_id"];

    final user = await store.findOne(
      query.fields(
        field,
      ),
    );

    if (user == null) {
      return Response.badRequest(body: "user is null ");
    }

    final userID = user["_id"] as ObjectId;

    final id = userID.toJson();

    final updateQuery = where.eq(
      "_id",
      ObjectId.fromHexString(id),
    );
    final username = await store.findOne(
      updateQuery.fields(
        ["user_name"],
      ),
    );
    final otp = int.parse(otpGenerator());
    await updateUserOtp(store, id: id, otp: otp);
    await sendOTPCode(otp, username?["user_name"], username?["email_address"]);
    return Response.ok(json.encode({
      "messages": {
        "details": {
          "context":
              "Congratulation your OTP has been sent to your email address.",
          "id": id,
          "otp": otp,
          "email": email
        }
      }
    }));
  }

//TODO: verify the otp endpoint.
  verifyOtp(Request req) async {
    final payload = await req.readAsString();

    final jsonData = json.decode(payload);
    final otp = jsonData["otp"];
    final id = jsonData["_id"];

    if (otp is! int? || id is! String?) {
      var response = {
        "error": {
          "message": {"_id": "Require this field", "otp": "Require this field"}
        }
      };

      if (otp is int?) {
        response["error"]?["message"]?.remove("otp");
        return Response.badRequest(
          body: json.encode(response),
          headers: {
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          },
        );
      }

      if (id is String?) {
        response["error"]?["message"]?.remove("_id");
        return Response.badRequest(
          body: json.encode(response),
          headers: {
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          },
        );
      }

      return Response.badRequest(
        body: json.encode(response),
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
        },
      );
    }
    var response = {
      "error": {
        "message": {"_id": "Require this field", "otp": "Require this field"}
      },
    };
    if (otp == null || id == null) {
      if (otp != null) {
        response["error"]?["message"]?.remove("otp");
        return Response.badRequest(
          body: json.encode(response),
          headers: {
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          },
        );
      }

      if (id != null) {
        response["error"]?["message"]?.remove("_id");
        return Response.badRequest(
          body: json.encode(response),
          headers: {
            HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          },
        );
      }

      return Response.badRequest(
        body: json.encode(response),
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
        },
      );
    }

    final newID = ObjectId.fromHexString(id);

    print(newID);
    print(otp);
    final querry = where.eq("_id", newID);

    final user = await store.findOne(querry.fields(["otp"]));

    if (user == null) {
      return Response.unauthorized(
        json.encode(
          {
            "error": {
              "message":
                  "Yor are not authorised to perform this action cause you do not have the valid credentials."
            }
          },
        ),
        headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      );
    }

    final cachedOtp = user["otp"];

    if (otp != cachedOtp) {
      var response = {
        "error": {
          "message": {
            "details": "Incorrect OTP",
          }
        }
      };

      return Response.badRequest(
        body: json.encode(response),
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
        },
      );
    }
    return Response.ok(
        json.encode(
          {
            "message": "successful",
          },
        ),
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
        });
  }

// TODO: forgot Password completion.

  forgotPasswordCompletion(Request req) async {
    if (req.isEmpty) {
      return Response.forbidden(
        json.encode(
          {"error": "request body is required"},
        ),
        headers: headers,
      );
    }

    final payload = await req.readAsString();
    final jsonData = json.decode(payload);
    final newPassword = jsonData["new_password"];
    final userID = jsonData["user_id"];

    var response = <String, dynamic>{
      "error": {
        "new_password": "require this field",
        "user_id": "require this field"
      }
    };

    if (newPassword == null || userID == null) {
      if (newPassword != null) {
        response["error"]?.remove("new_password");
        return Response.badRequest(
          body: json.encode(response),
          headers: headers,
        );
      }
      if (userID != null) {
        response["error"]?.remove("user_id");
        return Response.badRequest(
          body: json.encode(response),
          headers: headers,
        );
      }

      return Response.badRequest(
        body: json.encode(response),
        headers: headers,
      );
    }

    // Handle new password to know if its a String

    if (newPassword is! String?) {
      response = {
        "error": {
          "message": "Pasword requires a String",
        }
      };

      return Response.badRequest(
        body: json.encode(response),
        headers: headers,
      );
    }

    String? password = newPassword;
    final newSalt = genrateSalt();
    final hashedPassword = hashPassword(password!, newSalt);
    final id = ObjectId.fromHexString(userID);
    final query = where.eq("_id", id);

    await store.updateOne(
      query,
      modify.set("password", hashedPassword),
    );
    await store.updateOne(
      query,
      modify.set("salt", newSalt),
    );
    response = {
      "message": "password has been changed sucessfully",
    };

    return Response.ok(
      json.encode(response),
      headers: headers,
    );
  }

// TODO: log out

  logOut(Request req) async {
    final payload = await req.readAsString();
    var response = <String, dynamic>{};
    final jsonData = json.decode(payload);

    final authID = jsonData["auth_id"];

    if (authID == null) {
      response = {
        "error": {
          "message": {
            "auth_id": "required this field",
          }
        }
      };
      return Response.badRequest(
        body: json.encode(response),
        headers: headers,
      );
    }

    final id = ObjectId.fromHexString(authID);
    print(id);
    await store.updateOne(
      where.eq("_id", id),
      modify.set("logged_in", false),
    );
    response = {"message": "you have sucessfully logged out"};
    return Response.ok(json.encode(response), headers: headers);
  }
  // TODO: end of the class
}

void addRegisteredUser(DbCollection store,
    {required String email, required String userName}) async {
  final date = DateTime.now();

  final day = "${date.day}-${date.month}-${date.year}";
  final time = "${date.hour}:${date.minute}:${date.second}";

  await store.insertOne({
    "email_address": email,
    "user_name": userName,
    "created_at": "$day at $time",
    "updated_at": "$day  at $time",
    "is_subscribed": false,
    "bot_points": 10,
    "chat_history": <List<Map<String, String>>>[]
  });
}

Future<void> updateUserOtp(DbCollection store,
    {required String id, required int otp}) async {
  final updateQuery = where.eq(
    "_id",
    ObjectId.fromHexString(id),
  );
  final updateOtp = modify.set("otp", otp);
  await store.updateOne(updateQuery, updateOtp);
}

Future<void> sendOTPCode(int otp, String userName, String email) async {
  final username = "noreply@smartpayy.com";
  final password = "Samuelson200417";

  final smptSever = SmtpServer(
    "smtppro.zoho.com",
    username: username,
    password: password,
    port: 465,
    ssl: true,
  );

  final message = Message()
    ..from = Address(username)
    ..recipients.add(email)
    ..subject = "Forgot Password Recovery"
    ..html = """
<!DOCTYPE html>
<html>

<head>
    <title>Forgot Password Recovery</title>
    <style>
        body {
            background-color: #f8f8f8;
            font-family: Arial, sans-serif;
            color: #333;
            margin: 0;
        }

        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #fff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
        }

        h2 {
            color: #e91e63;
            text-align: center;
            margin-bottom: 20px;
        }

        p {
            font-size: 18px;
            line-height: 1.6;
            margin-bottom: 15px;
        }

        .otp-box {
            padding: 15px;
            background-color: #fce4ec;
            font-size: 32px;
            font-weight: bold;
            text-align: center;
            border-radius: 10px;
            color: #e91e63;
        }

        .highlight {
            font-weight: bold;
            color: #888;
        }

        .footer {
            margin-top: 30px;
            text-align: center;
            color: #888;
        }
    </style>
</head>

<body>
    <div class="container">
        
        <p>Hello <span class="highlight">$userName</span>,</p>
        <p>We received a request to reset your password. Please use the following One-Time Password (OTP) to reset
            your password:</p>
        <div class="otp-box">
            $otp
        </div>
        <p>If you didn't request a password reset, please ignore this email.</p>
        <p class="footer">Best regards,<br>Gobot AI Team</p>
    </div>
</body>

</html>

""";

  try {
    final sendReport = await send(message, smptSever);
    print("message sent:" + sendReport.toString());
  } on MailerException catch (err) {
    for (var p in err.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
  }
}

validateOTP(int otp, DbCollection store, String id) async {
  // final cachedOtp = user["otp"];
  // print(cachedOtp);
  return Response.ok("good");
}
