import 'package:flutter/material.dart';
import 'package:otp_auth/otp_auth.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/coming_soon.dart';
import '../catalog/categories_tab.dart';
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

  // La sesión vive a nivel de app; cada vez que alguien entra se carga su
  // perfil. Tras el primer frame: load() notifica de inmediato y no se puede
  // notificar a otros widgets mientras este se está construyendo.
  @override
  void initState() {
    super.initState();
    final session = context.read<UserSession>();
    WidgetsBinding.instance.addPostFrameCallback((_) => session.load());
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
          const _PlaceholderTab(
            title: 'Favoritos',
            icon: Icons.favorite_outline,
            message: 'Los productos que marques con ♥ aparecerán aquí.',
          ),
          const _PlaceholderTab(
            title: 'Carrito',
            icon: Icons.shopping_cart_outlined,
            message:
                'Tu carrito, agrupado por vendedor, para pedir por WhatsApp.',
          ),
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
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
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

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _PlaceholderTab({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ComingSoon(icon: icon, message: message),
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
