import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/session/user_session.dart';
import 'features/shell/home_shell.dart';

class HobbyStoreApp extends StatelessWidget {
  final OtpService otpService;
  final SessionStore sessionStore;
  final ApiClient api;

  const HobbyStoreApp({
    super.key,
    required this.otpService,
    required this.sessionStore,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    // Los providers van por encima de MaterialApp para que las pantallas que
    // se apilan con Navigator.push (producto, tienda, listados) los vean:
    // esas rutas son hermanas del Home, no hijas.
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider(create: (_) => UserSession(api)),
        Provider(create: (_) => CatalogRepository(api)),
      ],
      child: MaterialApp(
        title: 'Hobby Store',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: StartupScreen(
          auth: OtpAuth(
            otpService: otpService,
            sessionStore: sessionStore,
            homeBuilder: (context, auth, phone, isNewUser) {
              api.currentPhone = phone;
              return HomeShell(auth: auth);
            },
          ),
        ),
      ),
    );
  }
}
