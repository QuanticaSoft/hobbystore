import 'dart:convert';

import 'package:app_hobbystore/app.dart';
import 'package:app_hobbystore/features/cart/cart_store.dart';
import 'package:app_hobbystore/features/catalog/product_detail_screen.dart';
import 'package:app_hobbystore/features/favorites/favorites_store.dart';
import 'package:app_hobbystore/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// Backend falso con estado: favoritos y carrito se comportan como la API real
/// (agrupación por vendedor, stock, totales).
class FakeShop {
  final products = {
    1: {...productJson(1, title: 'Arrma Vorteks', price: 3150), 'stock': 2},
    2: {...productJson(2, title: 'Tamiya Novafox', price: 1290), 'stock': 5},
    3: {
      ...productJson(
        3,
        title: 'Jeep armado',
        price: 300,
        condition: 'used',
        sellerName: 'Ana Rojas',
        storeSlug: null,
      ),
      'stock': 1,
    },
  };
  final favorites = <int>[];
  final cart = <int, int>{};
  final requests = <String>[];

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/v1', '');
    requests.add('${request.method} $path');
    final segments = path.split('/');
    final id = segments.length > 2 ? int.tryParse(segments[2]) : null;

    switch ((request.method, segments.length > 1 ? segments[1] : '')) {
      case ('GET', 'me'):
        return jsonResponse({
          'user': userJson(displayName: 'Marco', city: 'La Paz'),
          'is_new': false,
        });
      case ('GET', 'home'):
        return jsonResponse({
          'banners': [],
          'featured_stores': [],
          'latest_products': products.values.toList(),
        });
      case ('GET', 'categories'):
        return jsonResponse({'categories': []});
      case ('GET', 'products'):
        return jsonResponse({'product': _detail(products[id]!)});
      case ('GET', 'favorites'):
        return jsonResponse({
          'items': [for (final f in favorites.reversed) products[f]],
        });
      case ('PUT', 'favorites'):
        if (!favorites.contains(id)) favorites.add(id!);
        return jsonResponse({'product_id': id, 'favorite': true});
      case ('DELETE', 'favorites'):
        favorites.remove(id);
        return jsonResponse({'product_id': id, 'favorite': false});
      case ('GET', 'cart'):
        return jsonResponse({'cart': _cart()});
      case ('PUT', 'cart'):
        final qty = (jsonDecode(request.body) as Map)['qty'] as int;
        final stock = products[id]!['stock'] as int;
        if (qty > stock) {
          return jsonResponse({
            'status': 'error',
            'message': 'Solo hay $stock disponible(s).',
          }, 409);
        }
        cart[id!] = qty;
        return jsonResponse({'cart': _cart()});
      case ('DELETE', 'cart'):
        cart.remove(id);
        return jsonResponse({'cart': _cart()});
    }
    return jsonResponse({'status': 'error', 'message': 'No encontrado.'}, 404);
  }

  Map<String, dynamic> _cart() {
    final groups = <String, Map<String, dynamic>>{};
    var total = 0.0;
    var count = 0;
    cart.forEach((id, qty) {
      final p = products[id]!;
      final line = (p['price_bob'] as num) * qty;
      final group = groups.putIfAbsent(
        p['seller_name'] as String,
        () => {
          'seller': {
            'type': p['store_slug'] == null ? 'user' : 'store',
            'name': p['seller_name'],
            'store_slug': p['store_slug'],
            'city': p['city'],
          },
          'items': <Map<String, dynamic>>[],
          'subtotal_bob': 0.0,
        },
      );
      (group['items'] as List).add({...p, 'qty': qty, 'line_total_bob': line});
      group['subtotal_bob'] = (group['subtotal_bob'] as double) + line;
      total += line;
      count += qty;
    });
    return {
      'groups': groups.values.toList(),
      'item_count': count,
      'total_bob': total,
    };
  }

  Map<String, dynamic> _detail(Map<String, dynamic> p) => {
    ...p,
    'description': '',
    'created_at': '2026-10-01',
    'category': {'slug': 'autos-rc', 'name': 'Autos y camiones RC'},
    'images': [],
    'seller': {
      'type': p['store_slug'] == null ? 'user' : 'store',
      'name': p['seller_name'],
      'city': p['city'],
      'store_slug': p['store_slug'],
      'logo_url': null,
      'delivery_options': [],
    },
  };
}

class _LoggedInOtpService extends MockOtpService {
  @override
  Future<SessionCheckResult> checkSession(String token) async =>
      const SessionCheckResult(
        status: SessionCheckStatus.valid,
        phone: '+59170000001',
      );
}

/// [setup] prepara el estado del servidor antes de que la app lo cargue.
Future<FakeShop> pumpApp(
  WidgetTester tester, {
  void Function(FakeShop shop)? setup,
}) async {
  usePhoneScreen(tester);
  final shop = FakeShop();
  setup?.call(shop);
  await tester.pumpWidget(
    HobbyStoreApp(
      otpService: _LoggedInOtpService(),
      sessionStore: InMemorySessionStore(testToken),
      api: fakeApi(shop.handle),
    ),
  );
  await settle(tester);
  return shop;
}

Future<void> openProduct(WidgetTester tester, int id) async {
  Navigator.of(
    tester.element(find.byType(HomeTab)),
  ).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: id)));
  await settle(tester);
  await tester.pumpAndSettle();
}

Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await settle(tester);
}

/// Badge del carrito en la barra de navegación.
Finder cartBadge(String count) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.widgetWithText(Badge, count),
);

void main() {
  testWidgets('el ♥ de una tarjeta guarda el favorito y aparece en la tab', (
    tester,
  ) async {
    final shop = await pumpApp(tester);

    await tester.tap(find.byTooltip('Agregar a favoritos').first);
    await settle(tester);

    expect(shop.favorites, [1]);
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);

    await goToTab(tester, 'Favoritos');
    expect(find.text('Arrma Vorteks'), findsWidgets);

    await tester.tap(find.byTooltip('Quitar de favoritos').last);
    await settle(tester);

    expect(shop.favorites, isEmpty);
    expect(
      find.text('Toca el ♥ de un producto para guardarlo aquí.'),
      findsOneWidget,
    );
  });

  testWidgets('añadir al carrito desde el detalle muestra el contador', (
    tester,
  ) async {
    final shop = await pumpApp(tester);
    await openProduct(tester, 1);

    await tester.tap(find.text('Añadir al carrito'));
    await settle(tester);

    expect(shop.cart, {1: 1});
    expect(find.text('Añadido al carrito.'), findsOneWidget);
    expect(find.text('Añadir otro (1 en el carrito)'), findsOneWidget);

    await tester.tap(find.text('Añadir otro (1 en el carrito)'));
    await settle(tester);

    expect(shop.cart, {1: 2});
    // Stock 2: con 2 en el carrito ya no se puede añadir otro.
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Añadir otro (2 en el carrito)'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(cartBadge('2'), findsOneWidget);
  });

  testWidgets('el carrito agrupa por vendedor y se edita con + / −', (
    tester,
  ) async {
    final shop = await pumpApp(
      tester,
      setup: (shop) => shop.cart.addAll({1: 1, 2: 1, 3: 1}),
    );
    await goToTab(tester, 'Carrito');

    expect(find.text('Garage RC'), findsOneWidget);
    expect(find.text('Ana Rojas'), findsOneWidget);
    expect(find.text('Bs 4.440'), findsOneWidget); // 3150 + 1290
    expect(
      find.text('3 producto(s) · 2 vendedor(es)', skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Uno más').first);
    await settle(tester);
    expect(shop.cart[1], 2);
    expect(find.text('Bs 7.590'), findsOneWidget); // 2×3150 + 1290

    // Con cantidad 1 el botón de la izquierda quita el producto.
    await tester.ensureVisible(find.byTooltip('Quitar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quitar').last);
    await settle(tester);
    expect(shop.cart.containsKey(3), isFalse);
    expect(find.text('Ana Rojas'), findsNothing);
  });

  testWidgets('sin stock suficiente se muestra el mensaje del servidor', (
    tester,
  ) async {
    final shop = await pumpApp(tester);
    shop.products[3]!['stock'] = 0;
    await openProduct(tester, 3);

    expect(find.text('Sin stock'), findsOneWidget);
    expect(shop.requests.where((r) => r.startsWith('PUT')), isEmpty);
  });

  testWidgets('cerrar sesión vacía favoritos y carrito', (tester) async {
    await pumpApp(
      tester,
      setup: (shop) {
        shop.cart[1] = 1;
        shop.favorites.add(2);
      },
    );
    expect(cartBadge('1'), findsOneWidget);

    await goToTab(tester, 'Perfil');
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    final appContext = tester.element(find.byType(MaterialApp));
    expect(Provider.of<CartStore>(appContext, listen: false).cart.itemCount, 0);
    expect(
      Provider.of<FavoritesStore>(appContext, listen: false).isFavorite(2),
      isFalse,
    );
  });
}
