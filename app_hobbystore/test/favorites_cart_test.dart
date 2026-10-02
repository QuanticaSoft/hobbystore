import 'package:app_hobbystore/features/cart/cart_store.dart';
import 'package:app_hobbystore/features/favorites/favorites_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_shop.dart';
import 'test_helpers.dart';

/// Badge del carrito en la barra de navegación.
Finder cartBadge(String count) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.widgetWithText(Badge, count),
);

void main() {
  testWidgets('el ♥ de una tarjeta guarda el favorito y aparece en la tab', (
    tester,
  ) async {
    final shop = await pumpShopApp(tester);

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
    final shop = await pumpShopApp(tester);
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
    final shop = await pumpShopApp(
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
    final shop = await pumpShopApp(tester);
    shop.products[3]!['stock'] = 0;
    await openProduct(tester, 3);

    expect(find.text('Sin stock'), findsOneWidget);
    expect(shop.requests.where((r) => r.startsWith('PUT')), isEmpty);
  });

  testWidgets('cerrar sesión vacía favoritos y carrito', (tester) async {
    await pumpShopApp(
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
