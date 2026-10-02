import 'package:app_hobbystore/core/format/price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_shop.dart';
import 'test_helpers.dart';

/// Abre la tab Carrito y la hoja de pedido del vendedor indicado.
Future<void> openOrderSheet(WidgetTester tester, String sellerName) async {
  await goToTab(tester, 'Carrito');
  final button = find.widgetWithText(FilledButton, 'Pedir a $sellerName');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> openProfileEntry(WidgetTester tester, String title) async {
  await goToTab(tester, 'Perfil');
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title));
  await settle(tester);
  await tester.pumpAndSettle();
}

Map<String, dynamic> receivedOrder() => {
  'id': 7,
  'status': 'pending',
  'role': 'seller',
  'total_bob': 650,
  'note': null,
  'created_at': '2026-10-02T10:00:00+00:00',
  'counterpart': {'name': 'Jorge Quispe', 'city': 'La Paz'},
  'is_store': false,
  'items': [
    {'product_id': 9, 'title': 'Fokker armado', 'price_bob': 650, 'qty': 1},
  ],
  'allowed_statuses': ['contacted', 'confirmed', 'cancelled'],
  'whatsapp_url': 'https://wa.me/59160000011?text=Hola',
};

void main() {
  testWidgets('pedir a un vendedor abre WhatsApp y lo quita del carrito', (
    tester,
  ) async {
    final links = FakeLinks();
    final shop = await pumpShopApp(
      tester,
      links: links,
      setup: (shop) => shop.cart.addAll({1: 2, 2: 1, 3: 1}),
    );

    await openOrderSheet(tester, 'Garage RC');
    expect(find.text('Pedido a Garage RC'), findsOneWidget);
    expect(find.text('3 producto(s) · ${formatBob(7590)}'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Retiro el sábado');
    await tester.tap(find.text('Enviar por WhatsApp'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(shop.orders.single['note'], 'Retiro el sábado');
    expect(links.opened.single.host, 'wa.me');
    expect(
      find.text('Pedido #1 creado. Síguelo en Perfil › Mis compras.'),
      findsOneWidget,
    );
    // Queda solo el grupo del particular.
    expect(shop.cart.keys, [3]);
    expect(find.text('Garage RC'), findsNothing);
    expect(find.text('Ana Rojas'), findsOneWidget);
  });

  testWidgets('sin nombre en el perfil el pedido se rechaza con el motivo', (
    tester,
  ) async {
    final links = FakeLinks();
    final shop = await pumpShopApp(
      tester,
      links: links,
      setup: (shop) {
        shop.cart[3] = 1;
        shop.displayName = null;
      },
    );

    await openOrderSheet(tester, 'Ana Rojas');
    await tester.tap(find.text('Enviar por WhatsApp'));
    await settle(tester);

    expect(
      find.text(
        'Completa tu nombre en Perfil para que el vendedor sepa quién pide.',
      ),
      findsOneWidget,
    );
    expect(links.opened, isEmpty);
    expect(shop.orders, isEmpty);
    expect(shop.cart, {3: 1});
  });

  testWidgets('si WhatsApp no abre, el pedido queda y se avisa dónde verlo', (
    tester,
  ) async {
    final links = FakeLinks()..succeeds = false;
    await pumpShopApp(tester, links: links, setup: (shop) => shop.cart[3] = 1);

    await openOrderSheet(tester, 'Ana Rojas');
    await tester.tap(find.text('Enviar por WhatsApp'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('no se pudo abrir WhatsApp'), findsOneWidget);
  });

  testWidgets('en Mis compras el comprador puede cancelar con confirmación', (
    tester,
  ) async {
    final shop = await pumpShopApp(tester, setup: (shop) => shop.cart[1] = 1);
    await openOrderSheet(tester, 'Garage RC');
    await tester.tap(find.text('Enviar por WhatsApp'));
    await settle(tester);
    await tester.pumpAndSettle();

    await openProfileEntry(tester, 'Mis compras');
    expect(find.text('Pedido #1'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing);

    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar el pedido #1?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar pedido'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(shop.orders.single['status'], 'cancelled');
    expect(find.text('Cancelado'), findsOneWidget);
  });

  testWidgets(
    'en Pedidos recibidos el vendedor confirma y escribe al comprador',
    (tester) async {
      final links = FakeLinks();
      final shop = await pumpShopApp(
        tester,
        links: links,
        setup: (shop) => shop.receivedOrders.add(receivedOrder()),
      );

      await openProfileEntry(tester, 'Pedidos recibidos');
      expect(find.text('Pedido #7'), findsOneWidget);
      expect(find.textContaining('Comprador: Jorge Quispe'), findsOneWidget);

      await tester.tap(find.text('Escribir al comprador'));
      await tester.pump();
      expect(
        links.opened.single.toString(),
        startsWith('https://wa.me/59160000011'),
      );

      await tester.tap(find.text('Confirmar'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(shop.receivedOrders.single['status'], 'confirmed');
      expect(find.text('Confirmado'), findsOneWidget);
    },
  );
}
