import 'package:app_hobbystore/features/profile/profile_tab.dart';
import 'package:app_hobbystore/features/store/store_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_shop.dart';
import 'test_helpers.dart';

Future<void> openProfileEntry(WidgetTester tester, String title) async {
  await goToTab(tester, 'Perfil');
  await scrollTo(tester, find.text(title), ProfileTab);
  await tester.tap(find.text(title));
  await settle(tester);
  await tester.pumpAndSettle();
}

Map<String, dynamic> storeJson({
  required String slug,
  required String name,
  String status = 'pending',
  bool featured = false,
  String? note,
}) => {
  'slug': slug,
  'name': name,
  'description': 'Aviones y repuestos',
  'city': 'Sucre',
  'whatsapp_phone': '+59170000055',
  'delivery_options': ['pickup'],
  'logo_url': null,
  'status': status,
  'is_featured': featured,
  'review_note': note,
  'owner_name': 'Luis Pérez',
  'owner_phone': '+59170000044',
  'product_count': 3,
  'created_at': '2026-10-02T10:00:00+00:00',
};

void main() {
  testWidgets('"Quiero ser tienda" envía la solicitud y queda en revisión', (
    tester,
  ) async {
    final shop = await pumpShopApp(tester);
    await openProfileEntry(tester, 'Mi tienda');
    expect(find.text('¿Importas o vendes seguido?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Quiero ser tienda'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la tienda'),
      'Hangar Sucre',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciudad'),
      'Sucre',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp para pedidos'),
      '70000055',
    );

    // Sin forma de entrega no se envía.
    final send = find.widgetWithText(FilledButton, 'Enviar solicitud');
    await scrollTo(tester, send, StoreFormScreen);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Elige al menos una forma de entrega.'), findsOneWidget);
    expect(shop.myStore, isNull);

    await scrollTo(
      tester,
      find.text('Envío nacional por encomienda'),
      StoreFormScreen,
    );
    await tester.tap(find.text('Envío nacional por encomienda'));
    await tester.tap(find.text('Retiro en tienda'));
    await tester.pump();
    await scrollTo(tester, send, StoreFormScreen);
    await tester.tap(send);
    await settle(tester);
    await tester.pumpAndSettle();

    expect(shop.myStore!['whatsapp_phone'], '+59170000055');
    // Siempre en el mismo orden, sin importar cuál se tocó primero.
    expect(shop.myStore!['delivery_options'], ['pickup', 'national']);
    expect(find.text('En revisión'), findsOneWidget);
  });

  testWidgets('una tienda suspendida muestra la nota del equipo', (
    tester,
  ) async {
    await pumpShopApp(
      tester,
      setup: (shop) => shop.myStore = storeJson(
        slug: 'mi-tienda',
        name: 'Hangar Sucre',
        status: 'suspended',
        note: 'Fotos con marca de agua.',
      ),
    );
    await openProfileEntry(tester, 'Mi tienda');

    expect(find.text('Suspendida'), findsOneWidget);
    expect(find.text('Fotos con marca de agua.'), findsOneWidget);
  });

  testWidgets('"Administración" solo aparece para admins', (tester) async {
    await pumpShopApp(tester);
    await goToTab(tester, 'Perfil');
    expect(find.text('Administración', skipOffstage: false), findsNothing);
  });

  testWidgets('el admin aprueba, destaca y suspende tiendas', (tester) async {
    final shop = await pumpShopApp(
      tester,
      setup: (shop) {
        shop.isAdmin = true;
        shop.adminStores.add(
          storeJson(slug: 'hangar-sucre', name: 'Hangar Sucre'),
        );
      },
    );
    await openProfileEntry(tester, 'Administración');

    expect(find.text('Hangar Sucre'), findsOneWidget);
    expect(find.textContaining('Luis Pérez'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Aprobar'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(shop.adminStores.single['status'], 'approved');
    expect(find.text('No hay tiendas en este estado.'), findsOneWidget);

    await tester.tap(find.text('Aprobadas'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(shop.adminStores.single['is_featured'], isTrue);

    await tester.tap(find.widgetWithText(TextButton, 'Suspender'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Precios engañosos.');
    await tester.tap(find.widgetWithText(FilledButton, 'Suspender'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(shop.adminStores.single['status'], 'suspended');
    expect(shop.adminStores.single['review_note'], 'Precios engañosos.');
  });

  testWidgets('el admin crea, oculta y borra banners', (tester) async {
    final shop = await pumpShopApp(
      tester,
      setup: (shop) => shop.isAdmin = true,
    );
    await openProfileEntry(tester, 'Administración');
    await tester.tap(find.text('Banners'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo banner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Festival RC Sucre');
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(shop.adminBanners.single['title'], 'Festival RC Sucre');
    expect(find.text('Festival RC Sucre'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(shop.adminBanners.single['active'], isFalse);
    expect(find.text('Oculto'), findsOneWidget);

    await tester.tap(find.byTooltip('Borrar banner'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(shop.adminBanners, isEmpty);
  });

  testWidgets('el admin retira una publicación desde el detalle', (
    tester,
  ) async {
    final shop = await pumpShopApp(
      tester,
      setup: (shop) => shop.isAdmin = true,
    );
    await openProduct(tester, 1);

    await tester.tap(find.byTooltip('Moderación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirar publicación (admin)'));
    await tester.pumpAndSettle();
    expect(find.text('¿Retirar "Arrma Vorteks"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(shop.removedProducts, [1]);
    expect(find.text('Publicación retirada.'), findsOneWidget);
  });

  testWidgets('un comprador común no ve la moderación', (tester) async {
    await pumpShopApp(tester);
    await openProduct(tester, 1);
    expect(find.byTooltip('Moderación'), findsNothing);
  });

  testWidgets('el dueño de una tienda ve que publica sin tope', (tester) async {
    await pumpShopApp(
      tester,
      setup: (shop) {
        shop.activeLimit = null;
        shop.myProducts.add({
          'id': 400,
          'title': 'Futaba 6J',
          'description': '',
          'price_bob': 850,
          'condition': 'new',
          'stock': 3,
          'status': 'active',
          'city': 'Sucre',
          'category': {'slug': 'radios-electronica', 'name': 'Radios'},
          'images': [
            {'id': 1, 'url': '', 'thumb_url': ''},
          ],
        });
      },
    );
    await openProfileEntry(tester, 'Mis publicaciones');

    expect(find.text('Publicas como tienda'), findsOneWidget);
    expect(find.textContaining('de 5 publicaciones activas'), findsNothing);
  });
}
