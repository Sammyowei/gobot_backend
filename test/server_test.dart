import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  final port = '2500';
  final host = 'http://0.0.0.0:$port';
  late Process? p;

  setUp(
    () async {
      try {
        p = await Process.start(
          'dart',
          ['run', 'bin/server.dart'],
          environment: {'PORT': port},
        );
        // Listen to server

        p?.stdout.listen((event) {
          print('Server stdout: ${String.fromCharCodes(event)}');
        });
        p?.stderr.listen((event) {
          print('Server stderr: ${String.fromCharCodes(event)}');
        });
        // Wait for server to start and print to stdout.
        await p!.stdout.first;
      } catch (e) {
        print("error starting server: $e");
      }
    },
  );

  tearDown(() => p!.kill());

  test('Root', () async {
    final response = await get(Uri.parse('$host/'));
    expect(response.statusCode, 200);
    expect(response.body, 'Hello, World!\n');
  });

  test('Echo', () async {
    final response = await get(Uri.parse('$host/echo/hello'));
    expect(response.statusCode, 200);
    expect(response.body, 'hello\n');
  });

  test('test', () async {
    final response = await post(Uri.parse("$host/print"),
        body: json.encode({
          "user_name": "TestUser",
          "password": "TestUSer1",
          "email_address": "user@test.com"
        }));

    expect(response.statusCode, 200);
    expect(
        response.body,
        jsonEncode({
          "message": {
            "user_name": "TestUser",
            "password": "TestUSer1",
            "email_address": "user@test.com"
          }
        }));
  });

  test('404', () async {
    final response = await get(Uri.parse('$host/foobar'));
    expect(response.statusCode, 404);
  });
}
