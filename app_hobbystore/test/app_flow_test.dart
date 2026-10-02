import 'package:app_hobbystore/app.dart';
import 'package:app_hobbystore/features/catalog/product_detail_screen.dart';
import 'package:app_hobbystore/features/home/home_tab.dart';
import 'package:app_hobbystore/features/session/user_session.dart';
import 'package:app_hobbystore/features/profile/profile_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// OTP falso con una sesión ya guardada y válida: la app entra directo al Home,
/// igual que en el teléfono al volver a abrirla.
class _LoggedInOtpService extends MockOtpService {
  @override
  Future<SessionCheckResult> checkSession(String token) async =>
      const SessionCheckResult(
        status: SessionCheckStatus.valid,
        phone: '+59170000001',
      );
}

final _handler = routes({
  '/me': {
    'user': userJson(displayName: 'Marco', city: 'La Paz'),
    'is_new': false,
  },
  '/home': homeJson(),
  '/categories': {'categories': []},
  '/products/1': {
    'product': {
      'id': 1,
      'title': 'Arrma Vorteks',
      'description': '',
      'price_bob': 3150,
      'condition': 'new',
      'stock': 4,
      'city': 'Santa Cruz',
      'created_at': '2026-10-01',
      'category': {'slug': 'autos-rc', 'name': 'Autos y camiones RC'},
      'images': [],
      'seller': {
        'type': 'store',
        'name': 'Garage RC',
        'city': 'Santa Cruz',
        'store_slug': 'garage-rc-scz',
        'logo_url': null,
        'delivery_options': ['pickup'],
      },
    },
  },
  '/stores/garage-rc-scz': {
    'store': {
      'slug': 'garage-rc-scz',
      'name': 'Garage RC',
      'city': 'Santa Cruz',
      'logo_url': null,
      'description': 'Autos y barcos RC.',
      'delivery_options': ['pickup'],
      'product_count': 1,
    },
  },
  '/products': {
    'items': [productJson(1, title: 'Arrma Vorteks', price: 3150)],
    'page': 1,
    'has_more': false,
  },
});

/// Monta la app completa, como corre en el teléfono (providers, rutas, login).
Future<void> pumpApp(
  WidgetTester tester, {
  Future<http.Response> Function(http.Request)? handler,
}) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    HobbyStoreApp(
      otpService: _LoggedInOtpService(),
      sessionStore: InMemorySessionStore(testToken),
      api: fakeApi(handler ?? _handler),
    ),
  );
  await settle(tester);
}

void expectNoError(WidgetTester tester) {
  final error = tester.takeException();
  expect(error, isNull, reason: '$error');
}

void main() {
  testWidgets('desde el Home se abre un producto y desde él, su tienda', (
    tester,
  ) async {
    await pumpApp(tester);

    // Igual que ProductCard: una ruta nueva sobre el Navigator de la app.
    // Antes del arreglo esto fallaba con ProviderNotFoundException.
    Navigator.of(tester.element(find.byType(HomeTab))).push(
      MaterialPageRoute(
        builder: (_) => const ProductDetailScreen(productId: 1),
      ),
    );
    await settle(tester);
    await tester.pumpAndSettle();

    expectNoError(tester);
    expect(find.text('Bs 3.150'), findsOneWidget);
    expect(find.text('Tienda · Santa Cruz'), findsOneWidget);

    // La tarjeta del vendedor queda bajo el botón fijo del carrito: se desplaza.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage RC'));
    await settle(tester);
    await tester.pumpAndSettle();

    expectNoError(tester);
    expect(find.text('Autos y barcos RC.'), findsOneWidget);
    expect(find.text('Santa Cruz · 1 productos'), findsOneWidget);
  });

  testWidgets('cerrar sesión pide confirmación y limpia el usuario', (
    tester,
  ) async {
    await pumpApp(tester);
    final session = Provider.of<UserSession>(
      tester.element(find.byType(HomeTab)),
      listen: false,
    );
    expect(session.user?.displayName, 'Marco');

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pump();
    await scrollTo(tester, find.text('Cerrar sesión'), ProfileTab);
    await tester.tap(find.text('Cerrar sesión'));
    await settle(tester);

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(find.text('¿Cerrar sesión?'), findsNothing);
    expect(session.user, isNotNull);

    await tester.tap(find.text('Cerrar sesión'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await settle(tester);
    await tester.pumpAndSettle();

    expectNoError(tester);
    expect(session.user, isNull);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
