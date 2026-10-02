import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:otp_auth/otp_auth.dart';

class ApiException implements Exception {
  /// 0 cuando no hubo respuesta del servidor (sin red, timeout).
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente de la API de Hobby Store. Adjunta el token de sesión de otp_auth
/// en `X-Session-Token`, porque PHP-FPM en flamenco no reenvía `Authorization`.
class ApiClient {
  static const _timeout = Duration(seconds: 15);

  final String baseUrl;
  final SessionStore sessionStore;

  /// Solo con el OTP mock: el servidor dev no puede validar tokens del mock y
  /// confía en el teléfono del usuario que entró (header `X-Dev-Phone`).
  final bool sendDevPhone;

  /// Teléfono del usuario con sesión; la app lo fija al entrar.
  String? currentPhone;

  final http.Client _client;

  ApiClient({
    required this.baseUrl,
    required this.sessionStore,
    this.sendDevPhone = false,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final request = http.Request(method, uri)..headers.addAll(await _headers());
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on SocketException {
      throw const ApiException(0, 'Sin conexión. Revisa tu internet.');
    } on TimeoutException {
      throw const ApiException(0, 'El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const ApiException(0, 'No se pudo conectar con el servidor.');
    }

    final Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        response.statusCode,
        'Respuesta inválida del servidor.',
      );
    }
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        response.statusCode,
        'Respuesta inválida del servidor.',
      );
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        data['message'] as String? ??
            'Error del servidor (${response.statusCode}).',
      );
    }
    return data;
  }

  Future<Map<String, String>> _headers() async {
    final token = await sessionStore.read();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Session-Token': ?token,
      if (sendDevPhone) 'X-Dev-Phone': ?currentPhone,
    };
  }
}
