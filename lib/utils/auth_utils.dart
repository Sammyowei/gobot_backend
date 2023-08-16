// ignore_for_file: prefer_typing_uninitialized_variables

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:gobot_backend/utils/jwt_util.dart';
import 'package:shelf/shelf.dart';

Middleware handleAuth(String secret) {
  return (innerHandler) {
    return (Request request) async {
      final authHandler = request.headers["Authorization"];
      var token, jwt;

      if (authHandler != null && authHandler.startsWith("Bearer ")) {
        token = authHandler.substring(7);
        jwt = verifyJWT(token, secret);
      }

      final updatedRequest = request.change(context: {"authDetails": jwt});
      return await innerHandler(updatedRequest);
    };
  };
}

Middleware checkAuthorization() {
  return createMiddleware(
    requestHandler: (Request request) {
      if (request.context["authDetail"] == null) {
        Response.forbidden(
          json.encode(
            {
              "error": {
                "message": "Not authorised to perform this action",
              }
            },
          ),
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
        );
      }
      return null;
    },
  );
}

String otpGenerator() {
  final int min = 10000;
  final int max = 99999;

  Random random = Random();

  int otp = min + random.nextInt(max-min);

  return otp.toString();
}
