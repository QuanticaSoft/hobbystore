// Mismo patrón que app_flutter/test/widget_test.dart: sin pumpAndSettle
// (OtpScreen tiene un Timer.periodic de 1s), se avanza el reloj en pasos
// acotados (delay del mock + transición de ruta).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_auth/otp_auth.dart';

const _routeTransition = Duration(milliseconds: 300);

Widget _app(OtpAuth auth) => MaterialApp(home: StartupScreen(auth: auth));

OtpAuth _auth(MockOtpService service, SessionStore store) => OtpAuth(
  otpService: service,
  sessionStore: store,
  homeBuilder: (context, auth, phone, isNewUser) => Scaffold(
    body: Column(
      children: [
        Text('home $phone ${isNewUser ? 'nuevo' : 'conocido'}'),
        TextButton(
          onPressed: () => auth.logout(context),
          child: const Text('logout'),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('login lleva a la home de la app y logout vuelve al número', (
    tester,
  ) async {
    final store = InMemorySessionStore();
    await tester.pumpWidget(_app(_auth(MockOtpService(), store)));
    await tester.pump();
    await tester.pump(_routeTransition);

    await tester.enterText(find.byKey(const Key('phoneField')), '71234567');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(_routeTransition);

    await tester.enterText(
      find.byKey(const Key('codeField')),
      MockOtpService.testCode,
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(_routeTransition);

    expect(find.text('home +59171234567 nuevo'), findsOneWidget);
    expect(await store.read(), isNotNull);

    await tester.tap(find.text('logout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(_routeTransition);

    expect(find.text('Verificar número'), findsOneWidget);
    expect(await store.read(), isNull);
  });

  testWidgets('con una sesión válida guardada entra directo a la home', (
    tester,
  ) async {
    final service = MockOtpService();
    final token = await tester.runAsync(() async {
      await service.requestOtp('+59171234567');
      final result = await service.verifyOtp(
        '+59171234567',
        MockOtpService.testCode,
      );
      return result.sessionToken;
    });

    await tester.pumpWidget(
      _app(_auth(service, InMemorySessionStore(token))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(_routeTransition);

    expect(find.text('home +59171234567 conocido'), findsOneWidget);
  });
}
