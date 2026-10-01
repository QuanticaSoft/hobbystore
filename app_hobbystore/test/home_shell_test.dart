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
  final session = UserSession(fakeApi(handler));
  final auth = OtpAuth(
    otpService: MockOtpService(),
    sessionStore: InMemorySessionStore(testToken),
    homeBuilder: (_, _, _, _) => const SizedBox(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: session,
        child: HomeShell(auth: auth),
      ),
    ),
  );
  await session.load();
  await tester.pump();
  return session;
}

void main() {
  testWidgets('muestra las 5 tabs y pide completar el perfil', (tester) async {
    await pumpShell(
      tester,
      (_) async => jsonResponse({'user': userJson(), 'is_new': true}),
    );

    for (final label in ['Inicio', 'Categorías', 'Favoritos', 'Carrito', 'Perfil']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    expect(find.text('Hola, hobbista'), findsOneWidget);
    expect(find.text('Completa tu perfil'), findsOneWidget);
  });

  testWidgets('"Completa tu perfil" lleva a la tab Perfil', (tester) async {
    await pumpShell(
      tester,
      (_) async => jsonResponse({'user': userJson(), 'is_new': true}),
    );

    await tester.tap(find.text('Completa tu perfil'));
    await tester.pump();

    expect(find.text('+59170000001'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nombre'), findsOneWidget);
  });

  testWidgets('guardar el perfil actualiza el saludo', (tester) async {
    await pumpShell(tester, (request) async {
      if (request.method == 'PATCH') {
        return jsonResponse({
          'user': userJson(displayName: 'Marco', city: 'La Paz'),
        });
      }
      return jsonResponse({'user': userJson(), 'is_new': true});
    });

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Marco');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'La Paz');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Perfil guardado.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Inicio'));
    await tester.pump();
    expect(find.text('Hola, Marco'), findsOneWidget);
    expect(find.text('Completa tu perfil'), findsNothing);
  });

  testWidgets('el formulario exige nombre y ciudad', (tester) async {
    final requests = <String>[];
    await pumpShell(tester, (request) async {
      requests.add(request.method);
      return jsonResponse({'user': userJson(), 'is_new': true});
    });

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();

    expect(find.text('Campo requerido'), findsNWidgets(2));
    expect(requests, isNot(contains('PATCH')));
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
}
