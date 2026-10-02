import 'dart:convert';

import 'package:app_hobbystore/app.dart';
import 'package:app_hobbystore/core/links/external_links.dart';
import 'package:app_hobbystore/core/photos/photo_picker.dart';
import 'package:app_hobbystore/features/catalog/product_detail_screen.dart';
import 'package:app_hobbystore/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:otp_auth/otp_auth.dart';

import 'test_helpers.dart';

/// Backend falso con estado: favoritos, carrito y pedidos se comportan como la
/// API real (agrupación por vendedor, stock, totales, transiciones de estado).
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
  final orders = <Map<String, dynamic>>[];
  final requests = <String>[];
  String? displayName = 'Marco';

  /// Pedidos que el usuario recibió como vendedor (role=seller).
  final receivedOrders = <Map<String, dynamic>>[];

  /// Publicaciones propias (vender) y fallos simulados de subida de fotos.
  final myProducts = <Map<String, dynamic>>[];
  int failNextUploads = 0;
  int _nextImageId = 1;

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/v1', '');
    requests.add('${request.method} $path');
    final segments = path.split('/');
    final id = segments.length > 2 ? int.tryParse(segments[2]) : null;

    if (segments.length > 2 && segments[1] == 'my') {
      return _myProducts(request, segments.sublist(3));
    }

    switch ((request.method, segments.length > 1 ? segments[1] : '')) {
      case ('GET', 'me'):
        return jsonResponse({
          'user': userJson(displayName: displayName, city: 'La Paz'),
          'is_new': false,
        });
      case ('GET', 'home'):
        return jsonResponse({
          'banners': [],
          'featured_stores': [],
          'latest_products': products.values.toList(),
        });
      case ('GET', 'categories'):
        return jsonResponse({
          'categories': [
            {
              'id': 1,
              'slug': 'aviones-rc',
              'name': 'Aviones RC',
              'product_count': 0,
            },
            {
              'id': 9,
              'slug': 'radios-electronica',
              'name': 'Radios y electrónica',
              'product_count': 0,
            },
          ],
        });
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
          return _error('Solo hay $stock disponible(s).', 409);
        }
        cart[id!] = qty;
        return jsonResponse({'cart': _cart()});
      case ('DELETE', 'cart'):
        cart.remove(id);
        return jsonResponse({'cart': _cart()});
      case ('POST', 'orders'):
        return _placeOrder(jsonDecode(request.body) as Map<String, dynamic>);
      case ('GET', 'orders'):
        final role = request.url.queryParameters['role'];
        return jsonResponse({
          'orders': role == 'seller'
              ? receivedOrders
              : orders.reversed.toList(),
        });
      case ('PATCH', 'orders'):
        final status = (jsonDecode(request.body) as Map)['status'] as String;
        final order = [
          ...orders,
          ...receivedOrders,
        ].firstWhere((o) => o['id'] == id);
        if (!(order['allowed_statuses'] as List).contains(status)) {
          return _error('No puedes cambiar este pedido a ese estado.', 409);
        }
        order['status'] = status;
        order['allowed_statuses'] = <String>[];
        return jsonResponse({'order': order});
    }
    return _error('No encontrado.', 404);
  }

  /// /v1/my/products[/{id}[/images[/{imageId}]]] con las reglas de la API:
  /// nace pausada, activar exige foto y stock, máximo 5 activas.
  http.Response _myProducts(http.Request request, List<String> rest) {
    final id = rest.isNotEmpty ? int.parse(rest[0]) : null;
    final product = id == null
        ? null
        : myProducts.firstWhere((p) => p['id'] == id);
    int activeCount() =>
        myProducts.where((p) => p['status'] == 'active').length;

    switch ((request.method, rest.length)) {
      case ('GET', 0):
        return jsonResponse({
          'products': myProducts.reversed.toList(),
          'active_count': activeCount(),
          'active_limit': 5,
        });
      case ('POST', 0):
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final created = {
          'id': 100 + myProducts.length,
          'title': body['title'],
          'description': body['description'],
          'price_bob': body['price_bob'],
          'condition': body['condition'],
          'stock': body['stock'],
          'status': 'paused',
          'city': 'La Paz',
          'category': {'slug': body['category'], 'name': 'Categoría'},
          'images': <Map<String, dynamic>>[],
        };
        myProducts.add(created);
        return jsonResponse({'product': created}, 201);
      case ('PATCH', 1):
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['status'] == 'active') {
          if ((product!['images'] as List).isEmpty) {
            return _error('Agrega al menos una foto para publicar.', 409);
          }
          if (product['status'] != 'active' && activeCount() >= 5) {
            return _error('Ya tienes 5 publicaciones activas.', 409);
          }
        }
        for (final entry in body.entries) {
          product![entry.key == 'category'
              ? 'category'
              : entry.key] = entry.key == 'category'
              ? {'slug': entry.value, 'name': 'Categoría'}
              : entry.value;
        }
        return jsonResponse({'product': product});
      case ('DELETE', 1):
        myProducts.remove(product);
        return jsonResponse({'product_id': id, 'status': 'removed'});
      case ('POST', 2):
        if (failNextUploads > 0) {
          failNextUploads--;
          return _error('No se pudo recibir la foto. Intenta de nuevo.', 400);
        }
        final imageId = _nextImageId++;
        (product!['images'] as List).add({
          'id': imageId,
          // Vacías: NetworkPicture muestra el ícono sin intentar descargar.
          'url': '',
          'thumb_url': '',
        });
        return jsonResponse({'product': product}, 201);
      case ('DELETE', 3):
        (product!['images'] as List).removeWhere(
          (image) => image['id'] == int.parse(rest[2]),
        );
        return jsonResponse({'product': product});
    }
    return _error('No encontrado.', 404);
  }

  static String groupKeyOf(Map<String, dynamic> product) =>
      product['store_slug'] == null
      ? 'user:${product['seller_name']}'
      : 'store:${product['store_slug']}';

  http.Response _placeOrder(Map<String, dynamic> body) {
    if (displayName == null) {
      return _error(
        'Completa tu nombre en Perfil para que el vendedor sepa quién pide.',
        400,
      );
    }
    final ids = cart.keys
        .where((id) => groupKeyOf(products[id]!) == body['group_key'])
        .toList();
    if (ids.isEmpty) {
      return _error('Esos productos ya no están en tu carrito.', 404);
    }
    final first = products[ids.first]!;
    final order = {
      'id': orders.length + 1,
      'status': 'pending',
      'role': 'buyer',
      'total_bob': ids.fold<num>(
        0,
        (sum, id) => sum + (products[id]!['price_bob'] as num) * cart[id]!,
      ),
      'note': body['note'],
      'created_at': '2026-10-02T14:21:56+00:00',
      'counterpart': {'name': first['seller_name'], 'city': first['city']},
      'is_store': first['store_slug'] != null,
      'items': [
        for (final id in ids)
          {
            'product_id': id,
            'title': products[id]!['title'],
            'price_bob': products[id]!['price_bob'],
            'qty': cart[id],
          },
      ],
      'allowed_statuses': ['cancelled'],
      'whatsapp_url': 'https://wa.me/59160000002?text=Pedido',
    };
    orders.add(order);
    ids.forEach(cart.remove);
    return jsonResponse({
      'order': order,
      'whatsapp_url': 'https://wa.me/59160000002?text=Pedido%20completo',
    }, 201);
  }

  Map<String, dynamic> _cart() {
    final groups = <String, Map<String, dynamic>>{};
    var total = 0.0;
    var count = 0;
    cart.forEach((id, qty) {
      final p = products[id]!;
      final line = (p['price_bob'] as num) * qty;
      final group = groups.putIfAbsent(
        groupKeyOf(p),
        () => {
          'key': groupKeyOf(p),
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

  static http.Response _error(String message, int status) =>
      jsonResponse({'status': 'error', 'message': message}, status);
}

/// Registra los enlaces que la app intentó abrir (WhatsApp).
class FakeLinks extends ExternalLinks {
  final opened = <Uri>[];
  bool succeeds = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeeds;
  }
}

/// PNG válido de 1×1: Image.memory necesita poder decodificar la vista previa.
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Devuelve fotos inventadas en lugar de abrir la galería o la cámara.
class FakePhotoPicker extends PhotoPicker {
  int galleryCalls = 0;

  @override
  Future<List<XFile>> pickFromGallery({required int max}) async {
    galleryCalls++;
    return [
      for (var i = 0; i < 2 && i < max; i++)
        XFile.fromData(_tinyPng, name: 'foto$i.jpg'),
    ];
  }

  @override
  Future<XFile?> takePhoto() async =>
      XFile.fromData(_tinyPng, name: 'camara.jpg');
}

/// OTP falso con una sesión ya guardada y válida: la app entra directo al Home,
/// igual que en el teléfono al volver a abrirla.
class LoggedInOtpService extends MockOtpService {
  @override
  Future<SessionCheckResult> checkSession(String token) async =>
      const SessionCheckResult(
        status: SessionCheckStatus.valid,
        phone: '+59170000001',
      );
}

/// Monta la app completa contra [FakeShop]. [setup] prepara el estado del
/// servidor antes de que la app lo cargue.
Future<FakeShop> pumpShopApp(
  WidgetTester tester, {
  void Function(FakeShop shop)? setup,
  FakeLinks? links,
  PhotoPicker? photoPicker,
}) async {
  usePhoneScreen(tester);
  final shop = FakeShop();
  setup?.call(shop);
  await tester.pumpWidget(
    HobbyStoreApp(
      otpService: LoggedInOtpService(),
      sessionStore: InMemorySessionStore(testToken),
      api: fakeApi(shop.handle),
      links: links ?? FakeLinks(),
      photoPicker: photoPicker ?? FakePhotoPicker(),
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
