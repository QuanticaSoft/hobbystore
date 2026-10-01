import 'dart:convert';

import 'package:app_hobbystore/core/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otp_auth/otp_auth.dart';

const testToken = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';

Map<String, dynamic> userJson({String? displayName, String? city}) => {
  'id': 1,
  'phone': '+59170000001',
  'display_name': displayName,
  'city': city,
  'is_admin': false,
};

/// [ApiClient] contra un servidor falso; [requests] guarda lo que se envió.
ApiClient fakeApi(
  Future<http.Response> Function(http.Request request) handler, {
  List<http.Request>? requests,
}) {
  return ApiClient(
    baseUrl: 'https://api.test/v1',
    sessionStore: InMemorySessionStore(testToken),
    client: MockClient((request) {
      requests?.add(request);
      return handler(request);
    }),
  );
}

http.Response jsonResponse(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
