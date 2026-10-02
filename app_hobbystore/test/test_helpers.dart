import 'dart:convert';

import 'package:app_hobbystore/core/api/api_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otp_auth/otp_auth.dart';

const testToken = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcde';

Map<String, dynamic> userJson({String? displayName, String? city}) => {
  'id': 1,
  'phone': '+59170000001',
  'display_name': displayName,
  'city': city,
  'is_admin': false,
};

/// [ApiClient] contra un servidor falso; [requests] guarda lo que se envió.
ApiClient fakeApi(
  Future<http.Response> Function(http.Request request) handler, {
  List<http.Request>? requests,
}) {
  return ApiClient(
    baseUrl: 'https://api.test/v1',
    sessionStore: InMemorySessionStore(testToken),
    client: MockClient((request) {
      requests?.add(request);
      return handler(request);
    }),
  );
}

http.Response jsonResponse(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Respuestas falsas por ruta (sin `/v1`); [requests] guarda lo que se pidió.
Future<http.Response> Function(http.Request) routes(
  Map<String, Map<String, dynamic>> responses, {
  Map<String, dynamic> Function(http.Request request)? onPatch,
}) {
  return (request) async {
    if (request.method == 'PATCH' && onPatch != null) {
      return jsonResponse(onPatch(request));
    }
    final path = request.url.path.replaceFirst('/v1', '');
    final body = {..._emptyUserLists, ...responses}[path];
    return body == null
        ? jsonResponse({'status': 'error', 'message': 'No encontrado.'}, 404)
        : jsonResponse(body);
  };
}

/// La shell carga favoritos y carrito al entrar; por defecto, vacíos.
const _emptyUserLists = {
  '/favorites': {'items': []},
  '/cart': {
    'cart': {'groups': [], 'item_count': 0, 'total_bob': 0},
  },
};

Map<String, dynamic> productJson(
  int id, {
  String title = 'Producto',
  double price = 100,
  String condition = 'new',
  String sellerName = 'Garage RC',
  String? storeSlug = 'garage-rc-scz',
}) => {
  'id': id,
  'title': title,
  'price_bob': price,
  'condition': condition,
  'city': 'Santa Cruz',
  'thumb_url': null,
  'seller_name': sellerName,
  'store_slug': storeSlug,
};

Map<String, dynamic> homeJson() => {
  'banners': [
    {
      'id': 1,
      'title': 'Convención Diecast',
      'image_url': null,
      'link_url': null,
    },
  ],
  'featured_stores': [
    {
      'slug': 'garage-rc-scz',
      'name': 'Garage RC',
      'city': 'Santa Cruz',
      'logo_url': null,
    },
  ],
  'latest_products': [
    productJson(1, title: 'Arrma Vorteks', price: 3150),
    productJson(
      2,
      title: 'Jeep armado',
      price: 300,
      condition: 'used',
      sellerName: 'Ana Rojas',
      storeSlug: null,
    ),
  ],
};

/// Deja avanzar las cargas asíncronas (cliente HTTP falso + FutureBuilder).
/// No usa pumpAndSettle porque los spinners animan sin fin mientras cargan.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pantalla de teléfono (360×800 lógicos). La de test por defecto (800×600)
/// es apaisada: la galería cuadrada deja fuera de vista el resto del detalle.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Desplaza el scroll dentro de [screen] hasta que [target] se vea. Con las
/// tabs en IndexedStack hay varios Scrollable montados: se usa el de [screen].
Future<void> scrollTo(WidgetTester tester, Finder target, Type screen) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}
