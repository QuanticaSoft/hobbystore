import 'package:app_hobbystore/app.dart';
import 'package:app_hobbystore/core/format/price.dart';
import 'package:app_hobbystore/features/catalog/catalog_models.dart';
import 'package:app_hobbystore/features/catalog/categories_tab.dart';
import 'package:app_hobbystore/features/catalog/product_detail_screen.dart';
import 'package:app_hobbystore/features/catalog/product_list_screen.dart';
import 'package:app_hobbystore/features/catalog/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'test_helpers.dart';

Future<void> pumpWithCatalog(
  WidgetTester tester,
  Widget child,
  Future<http.Response> Function(http.Request) handler,
) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    AppProviders(
      api: fakeApi(handler),
      child: MaterialApp(home: child),
    ),
  );
  await settle(tester);
}

Map<String, dynamic> detailJson({required bool fromStore}) => {
  'product': {
    'id': 7,
    'title': 'Diligencia del oeste armada',
    'description': 'Armada a mano.',
    'price_bob': 1250.5,
    'condition': fromStore ? 'new' : 'used',
    'stock': 1,
    'city': 'Cochabamba',
    'created_at': '2026-10-01',
    'category': {'slug': 'maquetas', 'name': 'Maquetas y estáticos'},
    'images': [],
    'seller': fromStore
        ? {
            'type': 'store',
            'name': 'Escala 1:35',
            'city': 'Cochabamba',
            'store_slug': 'escala-135-cbba',
            'logo_url': null,
            'delivery_options': ['pickup', 'national'],
          }
        : {
            'type': 'user',
            'name': 'Ana Rojas',
            'city': 'Cochabamba',
            'store_slug': null,
            'logo_url': null,
            'delivery_options': [],
          },
  },
};

void main() {
  group('formatBob', () {
    test('separa miles con punto y omite centavos en cero', () {
      expect(formatBob(3480), 'Bs 3.480');
      expect(formatBob(180), 'Bs 180');
      expect(formatBob(1234567), 'Bs 1.234.567');
    });

    test('muestra centavos con coma', () {
      expect(formatBob(1250.5), 'Bs 1.250,50');
      expect(formatBob(0.99), 'Bs 0,99');
    });
  });

  test('ProductFilter solo envía los filtros definidos', () {
    expect(const ProductFilter().toQuery(), isEmpty);
    expect(
      const ProductFilter(categorySlug: 'maquetas', query: 'tamiya').toQuery(),
      {'category': 'maquetas', 'q': 'tamiya'},
    );
  });

  testWidgets('Categorías lista y abre el listado filtrado', (tester) async {
    final requests = <http.Request>[];
    final handler = routes({
      '/categories': {
        'categories': [
          {
            'id': 1,
            'slug': 'aviones-rc',
            'name': 'Aviones RC',
            'product_count': 2,
          },
          {
            'id': 7,
            'slug': 'maquetas',
            'name': 'Maquetas y estáticos',
            'product_count': 10,
          },
        ],
      },
      '/products': {
        'items': [productJson(3, title: 'Tamiya M3 Stuart', price: 380)],
        'page': 1,
        'has_more': false,
      },
    });
    await pumpWithCatalog(tester, const CategoriesTab(), (request) {
      requests.add(request);
      return handler(request);
    });

    expect(find.text('Aviones RC'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.text('Maquetas y estáticos'));
    await tester.pumpAndSettle();

    expect(find.text('Tamiya M3 Stuart'), findsOneWidget);
    expect(requests.last.url.queryParameters, {
      'category': 'maquetas',
      'page': '1',
    });
  });

  testWidgets('el detalle de un producto de tienda muestra precio y entrega', (
    tester,
  ) async {
    await pumpWithCatalog(
      tester,
      const ProductDetailScreen(productId: 7),
      routes({'/products/7': detailJson(fromStore: true)}),
    );

    expect(find.text('Bs 1.250,50'), findsOneWidget);
    expect(find.text('Escala 1:35'), findsOneWidget);
    expect(find.text('Tienda · Cochabamba'), findsOneWidget);
    expect(find.text('• Retiro en tienda'), findsOneWidget);
    expect(find.text('• Envío nacional por encomienda'), findsOneWidget);
  });

  testWidgets('el detalle de un particular indica coordinar la entrega', (
    tester,
  ) async {
    await pumpWithCatalog(
      tester,
      const ProductDetailScreen(productId: 7),
      routes({'/products/7': detailJson(fromStore: false)}),
    );

    expect(find.text('Usado'), findsOneWidget);
    expect(find.text('Vendedor particular · Cochabamba'), findsOneWidget);
    expect(
      find.text('La entrega se coordina con el vendedor.'),
      findsOneWidget,
    );
  });

  testWidgets('un producto inexistente muestra el error del servidor', (
    tester,
  ) async {
    await pumpWithCatalog(
      tester,
      const ProductDetailScreen(productId: 999),
      (_) async => jsonResponse({
        'status': 'error',
        'message': 'Producto no encontrado.',
      }, 404),
    );

    expect(find.text('Producto no encontrado.'), findsOneWidget);
  });

  testWidgets('la búsqueda envía el texto y muestra "sin resultados"', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await pumpWithCatalog(tester, const SearchScreen(), (request) async {
      requests.add(request);
      return jsonResponse({'items': [], 'page': 1, 'has_more': false});
    });

    await tester.enterText(find.byType(TextField), '  spitfire ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    expect(requests.single.url.queryParameters['q'], 'spitfire');
    expect(find.text('Sin resultados para "spitfire".'), findsOneWidget);
  });

  testWidgets('el listado pide la página siguiente al llegar al final', (
    tester,
  ) async {
    final pages = <String>[];
    await pumpWithCatalog(tester, const ProductListScreen(title: 'Novedades'), (
      request,
    ) async {
      final page = request.url.queryParameters['page']!;
      pages.add(page);
      return jsonResponse(
        page == '1'
            ? {
                'items': [for (var i = 1; i <= 20; i++) productJson(i)],
                'page': 1,
                'has_more': true,
              }
            : {
                'items': [productJson(21, title: 'Último producto')],
                'page': 2,
                'has_more': false,
              },
      );
    });

    expect(pages, ['1']);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -6000),
      3000,
    );
    await settle(tester);

    expect(pages, ['1', '2']);
    await tester.scrollUntilVisible(
      find.text('Último producto'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Último producto'), findsOneWidget);
  });
}
