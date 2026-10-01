import 'dart:convert';

import 'package:app_hobbystore/core/api/api_client.dart';
import 'package:app_hobbystore/features/session/user_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'test_helpers.dart';

void main() {
  test('load trae el usuario y envía el token de sesión', () async {
    final requests = <http.Request>[];
    final session = UserSession(
      fakeApi(
        (_) async => jsonResponse({'user': userJson(), 'is_new': true}),
        requests: requests,
      ),
    );

    await session.load();

    expect(session.user?.phone, '+59170000001');
    expect(session.user?.isProfileComplete, isFalse);
    expect(session.isLoading, isFalse);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/v1/me');
    expect(requests.single.headers['X-Session-Token'], testToken);
    expect(requests.single.headers.containsKey('X-Dev-Phone'), isFalse);
  });

  test('load con 401 marca la sesión como expirada', () async {
    final session = UserSession(
      fakeApi(
        (_) async => jsonResponse({
          'status': 'error',
          'message': 'La sesión no es válida o expiró.',
        }, 401),
      ),
    );

    await session.load();

    expect(session.isExpired, isTrue);
    expect(session.user, isNull);
    expect(session.errorMessage, 'La sesión no es válida o expiró.');
  });

  test('load sin red deja un error sin expirar la sesión', () async {
    final session = UserSession(
      fakeApi((_) async => throw http.ClientException('sin red')),
    );

    await session.load();

    expect(session.isExpired, isFalse);
    expect(session.errorMessage, 'No se pudo conectar con el servidor.');
  });

  test('updateProfile envía PATCH y actualiza el usuario', () async {
    final requests = <http.Request>[];
    final session = UserSession(
      fakeApi(
        (request) async => jsonResponse({
          'user': userJson(displayName: 'Marco', city: 'La Paz'),
        }),
        requests: requests,
      ),
    );

    await session.updateProfile(displayName: 'Marco', city: 'La Paz');

    expect(requests.single.method, 'PATCH');
    expect(jsonDecode(requests.single.body), {
      'display_name': 'Marco',
      'city': 'La Paz',
    });
    expect(session.user?.isProfileComplete, isTrue);
  });

  test('updateProfile propaga el mensaje de error del servidor', () async {
    final session = UserSession(
      fakeApi(
        (_) async => jsonResponse({
          'status': 'error',
          'message': 'El nombre debe tener hasta 60 caracteres.',
        }, 400),
      ),
    );

    expect(
      () => session.updateProfile(displayName: 'x', city: 'y'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'El nombre debe tener hasta 60 caracteres.',
        ),
      ),
    );
  });
}
