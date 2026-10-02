import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/links/external_links.dart';
import 'core/theme/app_theme.dart';
import 'features/cart/cart_store.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/favorites/favorites_store.dart';
import 'features/orders/orders_repository.dart';
import 'features/session/user_session.dart';
import 'features/shell/home_shell.dart';

class HobbyStoreApp extends StatelessWidget {
  final OtpService otpService;
  final SessionStore sessionStore;
  final ApiClient api;
  final ExternalLinks links;

  const HobbyStoreApp({
    super.key,
    required this.otpService,
    required this.sessionStore,
    required this.api,
    this.links = const ExternalLinks(),
  });

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      api: api,
      links: links,
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

/// Estado compartido de la app, por encima de [MaterialApp]: las pantallas que
/// se apilan con Navigator.push (producto, tienda, listados) son rutas hermanas
/// del Home, no hijas, y solo así ven estos providers. Los tests lo usan para
/// montar exactamente el mismo árbol que la app.
class AppProviders extends StatelessWidget {
  final ApiClient api;
  final ExternalLinks links;
  final Widget child;

  const AppProviders({
    super.key,
    required this.api,
    required this.child,
    this.links = const ExternalLinks(),
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: links),
        ChangeNotifierProvider(create: (_) => UserSession(api)),
        Provider(create: (_) => CatalogRepository(api)),
        ChangeNotifierProvider(create: (_) => FavoritesStore(api)),
        ChangeNotifierProvider(create: (_) => CartStore(api)),
        Provider(create: (_) => OrdersRepository(api)),
      ],
      child: child,
    );
  }
}
