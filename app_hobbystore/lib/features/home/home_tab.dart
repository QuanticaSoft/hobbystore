import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/coming_soon.dart';
import '../session/user_session.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onCompleteProfile;

  const HomeTab({super.key, required this.onCompleteProfile});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserSession>().user;
    final greeting = user?.displayName == null
        ? 'Hola, hobbista'
        : 'Hola, ${user!.displayName}';

    return Scaffold(
      appBar: AppBar(title: const Text('Hobby Store')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
          if (user != null && !user.isProfileComplete) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Completa tu perfil'),
                subtitle: const Text(
                  'Tu nombre y ciudad ayudan a los vendedores a coordinar contigo.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: onCompleteProfile,
              ),
            ),
          ],
          const SizedBox(height: 48),
          const ComingSoon(
            icon: Icons.storefront_outlined,
            message: 'Pronto: tiendas, eventos y las novedades del hobby.',
          ),
        ],
      ),
    );
  }
}
