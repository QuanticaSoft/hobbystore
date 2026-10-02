import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../catalog/catalog_models.dart';

/// Favoritos del usuario. El corazón cambia al instante (optimista) y vuelve
/// atrás si el servidor rechaza el cambio.
class FavoritesStore extends ChangeNotifier {
  final ApiClient api;

  FavoritesStore(this.api);

  final Set<int> _ids = {};
  List<ProductSummary> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductSummary> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isFavorite(int productId) => _ids.contains(productId);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await api.get('/favorites');
      _items = (data['items'] as List)
          .map((json) => ProductSummary.fromJson(json as Map<String, dynamic>))
          .toList();
      _ids
        ..clear()
        ..addAll(_items.map((product) => product.id));
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lanza [ApiException] si el servidor rechaza el cambio (ya revertido).
  Future<void> toggle(int productId) async {
    final wasFavorite = _ids.contains(productId);
    _setLocal(productId, favorite: !wasFavorite);
    try {
      if (wasFavorite) {
        await api.delete('/favorites/$productId');
      } else {
        await api.put('/favorites/$productId');
        // La lista necesita los datos del producto: se recarga en segundo plano.
        load();
      }
    } on ApiException {
      _setLocal(productId, favorite: wasFavorite);
      rethrow;
    }
  }

  void clear() {
    _ids.clear();
    _items = [];
    _errorMessage = null;
    notifyListeners();
  }

  void _setLocal(int productId, {required bool favorite}) {
    if (favorite) {
      _ids.add(productId);
    } else {
      _ids.remove(productId);
      _items = _items.where((product) => product.id != productId).toList();
    }
    notifyListeners();
  }
}
