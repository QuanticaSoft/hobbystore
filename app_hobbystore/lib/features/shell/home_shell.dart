import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import '../cart/cart_store.dart';
import '../cart/cart_tab.dart';
import '../catalog/categories_tab.dart';
import '../favorites/favorites_store.dart';
import '../favorites/favorites_tab.dart';
import '../home/home_tab.dart';
import '../profile/profile_tab.dart';
import '../session/log_out.dart';
import '../session/user_session.dart';

class HomeShell extends StatefulWidget {
  final OtpAuth auth;

  const HomeShell({super.key, required this.auth});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const profileTabIndex = 4;

  int _selectedIndex = 0;

  // La sesión vive a nivel de app; cada vez que alguien entra se cargan su
  // perfil, favoritos y carrito. Tras el primer frame: load() notifica de inmediato y no se puede
  // notificar a otros widgets mientras este se está construyendo.
  @override
  void initState() {
    super.initState();
    final session = context.read<UserSession>();
    final favorites = context.read<FavoritesStore>();
    final cart = context.read<CartStore>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      session.load();
      favorites.load();
      cart.load();
    });
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    if (session.isExpired) return _ExpiredSession(auth: widget.auth);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeTab(onCompleteProfile: () => _selectTab(profileTabIndex)),
          const CategoriesTab(),
          const FavoritesTab(),
          const CartTab(),
          ProfileTab(auth: widget.auth),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categorías',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: _CartIcon(selected: false),
            selectedIcon: _CartIcon(selected: true),
            label: 'Carrito',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Ícono del carrito con la cantidad de productos.
class _CartIcon extends StatelessWidget {
  final bool selected;

  const _CartIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartStore, int>(
      (store) => store.cart.itemCount,
    );
    return Badge.count(
      count: count,
      isLabelVisible: count > 0,
      child: Icon(
        selected ? Icons.shopping_cart : Icons.shopping_cart_outlined,
      ),
    );
  }
}

class _ExpiredSession extends StatelessWidget {
  final OtpAuth auth;

  const _ExpiredSession({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tu sesión expiró. Ingresa de nuevo con tu número.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => logOut(context, auth),
                child: const Text('Ingresar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
