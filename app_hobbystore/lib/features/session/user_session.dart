import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import 'user.dart';

/// Usuario autenticado de Hobby Store (`/v1/me`), compartido por todas las tabs.
class UserSession extends ChangeNotifier {
  final ApiClient api;

  UserSession(this.api);

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isExpired = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// El servidor rechazó el token: hay que volver a pedir el OTP.
  bool get isExpired => _isExpired;

  Future<void> load() async {
    _isLoading = true;
    _isExpired = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await api.get('/me');
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      _isExpired = e.isUnauthorized;
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Olvida al usuario al cerrar sesión: la sesión vive a nivel de app y el
  /// próximo login no debe ver los datos del anterior.
  void clear() {
    _user = null;
    _errorMessage = null;
    _isExpired = false;
    notifyListeners();
  }

  /// Lanza [ApiException] para que el formulario muestre el error en su lugar.
  Future<void> updateProfile({
    required String displayName,
    required String city,
  }) async {
    final data = await api.patch('/me', {
      'display_name': displayName,
      'city': city,
    });
    _user = User.fromJson(data['user'] as Map<String, dynamic>);
    notifyListeners();
  }
}
