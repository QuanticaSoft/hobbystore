import 'package:flutter/material.dart';

import 'screens/phone_screen.dart';
import 'services/otp_service.dart';
import 'services/session_store.dart';

/// Pantalla a la que entra cada app tras un login correcto (o con una
/// sesión guardada válida): es lo único que cambia entre apps. Recibe el
/// propio [OtpAuth] para que esa pantalla pueda cerrar sesión.
typedef HomeBuilder =
    Widget Function(
      BuildContext context,
      OtpAuth auth,
      String phone,
      bool isNewUser,
    );

/// Todo lo que necesitan las pantallas de login, agrupado para no pasar
/// servicio, store y destino por separado a cada pantalla.
class OtpAuth {
  final OtpService otpService;
  final SessionStore sessionStore;
  final HomeBuilder homeBuilder;

  const OtpAuth({
    required this.otpService,
    required this.sessionStore,
    required this.homeBuilder,
  });

  /// Revoca la sesión en el servidor, borra el token y vuelve a pedir el
  /// número, descartando todo el historial de navegación.
  Future<void> logout(BuildContext context) async {
    final token = await sessionStore.read();
    if (token != null) await otpService.logout(token);
    await sessionStore.clear();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => PhoneScreen(auth: this)),
      (_) => false,
    );
  }
}
