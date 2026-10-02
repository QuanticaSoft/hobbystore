import 'package:app_hobbystore/features/profile/profile_tab.dart';
import 'package:app_hobbystore/features/sell/product_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_shop.dart';
import 'test_helpers.dart';

Future<void> openMyProducts(WidgetTester tester) async {
  await goToTab(tester, 'Perfil');
  await scrollTo(tester, find.text('Mis publicaciones'), ProfileTab);
  await tester.tap(find.text('Mis publicaciones'));
  await settle(tester);
  await tester.pumpAndSettle();
}

/// Completa el formulario de publicación (sin fotos).
Future<void> fillForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Título'),
    'Futaba 6J usada',
  );
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Radios y electrónica').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Precio'), '850');
}

Future<void> tapPublish(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Publicar');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await settle(tester);
  await tester.pumpAndSettle();
}

Future<void> openNewForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Publicar'));
  await settle(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('parsePrice', () {
    test('acepta enteros, miles con punto y decimales', () {
      expect(parsePrice('1250'), 1250);
      expect(parsePrice('1.250'), 1250);
      expect(parsePrice('12.500'), 12500);
      expect(parsePrice('1.250,50'), 1250.5);
      expect(parsePrice('12,5'), 12.5);
      expect(parsePrice('12.5'), 12.5);
      expect(parsePrice('abc'), isNull);
    });
  });

  testWidgets('publicar: crea pausada, sube las fotos y la activa', (
    tester,
  ) async {
    final shop = await pumpShopApp(tester);
    await openMyProducts(tester);
    expect(find.textContaining('Aún no publicaste nada'), findsOneWidget);

    await openNewForm(tester);
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos (2 de 5)'), findsOneWidget);

    await fillForm(tester);
    shop.requests.clear();
    await tapPublish(tester);

    expect(shop.requests.where((r) => r.contains('/my/products')).toList(), [
      'POST /my/products',
      'POST /my/products/100/images',
      'POST /my/products/100/images',
      'PATCH /my/products/100',
      'GET /my/products',
    ]);
    expect(shop.myProducts.single['status'], 'active');
    expect(find.textContaining('Futaba 6J usada'), findsOneWidget);
    expect(find.textContaining('Publicada'), findsOneWidget);
    expect(find.text('1 de 5 publicaciones activas'), findsOneWidget);
  });

  testWidgets('sin fotos no se envía nada', (tester) async {
    final shop = await pumpShopApp(tester);
    await openMyProducts(tester);
    await openNewForm(tester);
    await fillForm(tester);
    shop.requests.clear();

    await tapPublish(tester);

    expect(find.text('Agrega al menos una foto.'), findsOneWidget);
    expect(shop.requests, isEmpty);
  });

  testWidgets('si falla una foto, reintentar no duplica la publicación', (
    tester,
  ) async {
    final shop = await pumpShopApp(
      tester,
      setup: (shop) => shop.failNextUploads = 1,
    );
    await openMyProducts(tester);
    await openNewForm(tester);
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    await fillForm(tester);

    await tapPublish(tester);
    expect(
      find.textContaining('Tu publicación quedó guardada como pausada.'),
      findsOneWidget,
    );
    expect(shop.myProducts.single['status'], 'paused');

    shop.requests.clear();
    await tapPublish(tester);

    expect(shop.myProducts, hasLength(1));
    expect(shop.myProducts.single['status'], 'active');
    expect((shop.myProducts.single['images'] as List), hasLength(2));
    expect(shop.requests.where((r) => r == 'POST /my/products'), isEmpty);
  });

  testWidgets('con 5 activas, la nueva queda pausada con el motivo', (
    tester,
  ) async {
    final shop = await pumpShopApp(
      tester,
      setup: (shop) {
        for (var i = 0; i < 5; i++) {
          shop.myProducts.add({
            'id': 200 + i,
            'title': 'Activa $i',
            'description': '',
            'price_bob': 10,
            'condition': 'used',
            'stock': 1,
            'status': 'active',
            'city': 'La Paz',
            'category': {'slug': 'aviones-rc', 'name': 'Aviones RC'},
            'images': [
              {'id': 900 + i, 'url': '', 'thumb_url': ''},
            ],
          });
        }
      },
    );
    await openMyProducts(tester);
    expect(find.text('5 de 5 publicaciones activas'), findsOneWidget);

    await openNewForm(tester);
    await tester.tap(find.text('Cámara'));
    await tester.pumpAndSettle();
    await fillForm(tester);
    await tapPublish(tester);

    expect(
      find.textContaining('Ya tienes 5 publicaciones activas.'),
      findsOneWidget,
    );
    expect(find.textContaining('quedó guardada como pausada'), findsOneWidget);
    expect(shop.myProducts.last['status'], 'paused');
  });

  testWidgets('desde el menú se marca vendida y se elimina con confirmación', (
    tester,
  ) async {
    final shop = await pumpShopApp(
      tester,
      setup: (shop) => shop.myProducts.add({
        'id': 300,
        'title': 'Spitfire armado',
        'description': '',
        'price_bob': 400,
        'condition': 'used',
        'stock': 1,
        'status': 'active',
        'city': 'La Paz',
        'category': {'slug': 'aviones-rc', 'name': 'Aviones RC'},
        'images': [
          {'id': 1, 'url': '', 'thumb_url': ''},
        ],
      }),
    );
    await openMyProducts(tester);

    await tester.tap(find.byTooltip('Acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar vendida'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(shop.myProducts.single['status'], 'sold');
    expect(find.textContaining('Vendida'), findsOneWidget);

    await tester.tap(find.byTooltip('Acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar "Spitfire armado"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(shop.myProducts, isEmpty);
    expect(find.textContaining('Aún no publicaste nada'), findsOneWidget);
  });
}
