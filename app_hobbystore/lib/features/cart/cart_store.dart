import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import 'cart_models.dart';

/// Carrito del usuario, compartido por el detalle de producto, la tab Carrito
/// y el contador de la barra de navegación. El servidor es la fuente de verdad:
/// cada cambio devuelve el carrito completo con subtotales ya calculados.
class CartStore extends ChangeNotifier {
  final ApiClient api;

  CartStore(this.api);

  Cart _cart = Cart.empty;
  bool _isLoading = false;
  String? _errorMessage;
  final Set<int> _busyProductIds = {};

  Cart get cart => _cart;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Productos con un cambio en curso: sus controles se deshabilitan.
  bool isBusy(int productId) => _busyProductIds.contains(productId);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _cart = await _fetch(() => api.get('/cart'));
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Suma una unidad. Lanza [ApiException] (p. ej. sin stock) para mostrarla.
  Future<void> add(int productId) =>
      setQuantity(productId, _cart.quantityOf(productId) + 1);

  Future<void> setQuantity(int productId, int qty) =>
      _change(productId, () => api.put('/cart/$productId', {'qty': qty}));

  Future<void> remove(int productId) =>
      _change(productId, () => api.delete('/cart/$productId'));

  void clear() {
    _cart = Cart.empty;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _change(
    int productId,
    Future<Map<String, dynamic>> Function() request,
  ) async {
    _busyProductIds.add(productId);
    notifyListeners();
    try {
      _cart = await _fetch(request);
    } finally {
      _busyProductIds.remove(productId);
      notifyListeners();
    }
  }

  Future<Cart> _fetch(Future<Map<String, dynamic>> Function() request) async =>
      Cart.fromJson((await request())['cart'] as Map<String, dynamic>);
}
