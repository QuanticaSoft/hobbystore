import 'package:app_hobbystore/app.dart';
import 'package:app_hobbystore/features/session/user_session.dart';
import 'package:app_hobbystore/features/shell/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

Future<UserSession> pumpShell(
  WidgetTester tester,
  Future<http.Response> Function(http.Request request) handler,
) async {
  usePhoneScreen(tester);
  final api = fakeApi(handler);
  final auth = OtpAuth(
    otpService: MockOtpService(),
    sessionStore: InMemorySessionStore(testToken),
    homeBuilder: (_, _, _, _) => const SizedBox(),
  );

  await tester.pumpWidget(
    AppProviders(
      api: api,
      child: MaterialApp(home: HomeShell(auth: auth)),
    ),
  );
  final session = Provider.of<UserSession>(
    tester.element(find.byType(HomeShell)),
    listen: false,
  );
  await session.load();
  await settle(tester);
  return session;
}

Map<String, Map<String, dynamic>> baseRoutes({Map<String, dynamic>? user}) => {
  '/me': {'user': user ?? userJson(), 'is_new': true},
  '/home': homeJson(),
  '/categories': {'categories': []},
};

void main() {
  testWidgets('muestra las 5 tabs y el Home con banners, tiendas y novedades', (
    tester,
  ) async {
    await pumpShell(tester, routes(baseRoutes()));

    for (final label in [
      'Inicio',
      'Categorías',
      'Favoritos',
      'Carrito',
      'Perfil',
    ]) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    expect(find.text('Completa tu perfil'), findsOneWidget);
    expect(find.text('Convención Diecast'), findsOneWidget);
    expect(find.text('Tiendas'), findsOneWidget);
    expect(find.text('Novedades'), findsOneWidget);
    // La grilla queda bajo el borde de la pantalla: se construye pero no se ve.
    expect(find.text('Bs 3.150', skipOffstage: false), findsOneWidget);
    expect(find.text('Usado', skipOffstage: false), findsOneWidget);
  });

  testWidgets('"Completa tu perfil" lleva a la tab Perfil', (tester) async {
    await pumpShell(tester, routes(baseRoutes()));

    await tester.tap(find.text('Completa tu perfil'));
    await tester.pump();

    expect(find.text('+59170000001'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nombre'), findsOneWidget);
  });

  testWidgets('guardar el perfil quita el aviso del Home', (tester) async {
    await pumpShell(
      tester,
      routes(
        baseRoutes(),
        onPatch: (_) => {
          'user': userJson(displayName: 'Marco', city: 'La Paz'),
        },
      ),
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Marco',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciudad'),
      'La Paz',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await settle(tester);

    expect(find.text('Perfil guardado.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Inicio'));
    await tester.pump();
    expect(find.text('Completa tu perfil'), findsNothing);
  });

  testWidgets('el formulario exige nombre y ciudad', (tester) async {
    final methods = <String>[];
    final handler = routes(baseRoutes());
    await pumpShell(tester, (request) {
      methods.add(request.method);
      return handler(request);
    });

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();

    expect(find.text('Campo requerido'), findsNWidgets(2));
    expect(methods, isNot(contains('PATCH')));
  });

  testWidgets('una sesión expirada pide volver a ingresar', (tester) async {
    await pumpShell(
      tester,
      (_) async => jsonResponse({
        'status': 'error',
        'message': 'La sesión no es válida o expiró.',
      }, 401),
    );

    expect(
      find.text('Tu sesión expiró. Ingresa de nuevo con tu número.'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('si el Home falla se puede reintentar', (tester) async {
    var homeCalls = 0;
    await pumpShell(tester, (request) async {
      if (request.url.path.endsWith('/home')) {
        homeCalls++;
        if (homeCalls == 1) {
          return jsonResponse({
            'status': 'error',
            'message': 'Servidor caído.',
          }, 500);
        }
        return jsonResponse(homeJson());
      }
      return routes(baseRoutes())(request);
    });

    expect(find.text('Servidor caído.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
    await settle(tester);

    expect(find.text('Novedades'), findsOneWidget);
  });
}
