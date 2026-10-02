import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/session/user_session.dart';
import 'features/shell/home_shell.dart';

/// Crea el cliente de la API para el usuario que acaba de entrar; recibe el
/// teléfono porque el OTP mock lo necesita (ver [ApiClient.devPhone]).
typedef ApiClientBuilder = ApiClient Function(String phone);

class HobbyStoreApp extends StatelessWidget {
  final OtpService otpService;
  final SessionStore sessionStore;
  final ApiClientBuilder apiClientBuilder;

  const HobbyStoreApp({
    super.key,
    required this.otpService,
    required this.sessionStore,
    required this.apiClientBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hobby Store',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: StartupScreen(
        auth: OtpAuth(
          otpService: otpService,
          sessionStore: sessionStore,
          // La sesión vive debajo de la ruta de inicio: al cerrar sesión,
          // otp_auth reemplaza la ruta y el provider se descarta con ella.
          homeBuilder: (context, auth, phone, isNewUser) {
            final api = apiClientBuilder(phone);
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => UserSession(api)..load()),
                Provider(create: (_) => CatalogRepository(api)),
              ],
              child: HomeShell(auth: auth),
            );
          },
        ),
      ),
    );
  }
}
