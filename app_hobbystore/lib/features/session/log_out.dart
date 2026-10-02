import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../cart/cart_store.dart';
import '../favorites/favorites_store.dart';
import 'user_session.dart';

/// Cierra la sesión: revoca el token (otp_auth) y limpia el estado de la app,
/// que vive por encima de las rutas y sobreviviría al cambio de usuario.
///
/// Se limpia después de navegar: limpiar antes reconstruye el perfil, desmonta
/// el [context] y otp_auth cancela la navegación al login.
Future<void> logOut(BuildContext context, OtpAuth auth) async {
  final session = context.read<UserSession>();
  final favorites = context.read<FavoritesStore>();
  final cart = context.read<CartStore>();
  final api = context.read<ApiClient>();
  await auth.logout(context);
  session.clear();
  favorites.clear();
  cart.clear();
  api.currentPhone = null;
}

/// Pide confirmación antes de cerrar sesión: volver a entrar exige un código
/// SMS nuevo, y para salir de la app basta con cerrarla (la sesión se guarda).
Future<void> confirmLogOut(BuildContext context, OtpAuth auth) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: const Text(
        'Para volver a entrar tendrás que verificar tu número con un código '
        'SMS nuevo.\n\nSi solo quieres salir de la app, ciérrala normalmente: '
        'tu sesión queda guardada y al abrirla entrarás directo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) await logOut(context, auth);
}
