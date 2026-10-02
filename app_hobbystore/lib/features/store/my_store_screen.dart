import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/error_retry.dart';
import '../../core/widgets/network_picture.dart';
import '../catalog/catalog_models.dart';
import '../catalog/store_screen.dart';
import 'my_store_models.dart';
import 'my_store_repository.dart';
import 'store_form_screen.dart';

class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({super.key});

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  late Future<MyStore?> _store;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _store = context.read<MyStoreRepository>().get();
  }

  void _reload() => setState(() {
    _store = context.read<MyStoreRepository>().get();
  });

  Future<void> _openForm([MyStore? store]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StoreFormScreen(existing: store)),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi tienda')),
      body: FutureBuilder(
        future: _store,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorRetry(
              message: errorMessageOf(snapshot.error),
              onRetry: _reload,
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final store = snapshot.data;
          return store == null
              ? _NoStore(onApply: _openForm)
              : _StoreStatus(store: store, onEdit: () => _openForm(store));
        },
      ),
    );
  }
}

class _NoStore extends StatelessWidget {
  final VoidCallback onApply;

  const _NoStore({required this.onApply});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '¿Importas o vendes seguido?',
          textAlign: TextAlign.center,
          style: textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Con una tienda aprobada:\n'
          '• Publicas sin límite.\n'
          '• Tu logo puede aparecer en el Inicio.\n'
          '• Los pedidos llegan al WhatsApp de tu negocio.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onApply,
          child: const Text('Quiero ser tienda'),
        ),
      ],
    );
  }
}

class _StoreStatus extends StatelessWidget {
  final MyStore store;
  final VoidCallback onEdit;

  const _StoreStatus({required this.store, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reviewNote = store.reviewNote;
    final (icon, message) = switch (store.status) {
      'pending' => (
        Icons.hourglass_top,
        'Estamos revisando tu solicitud. Te avisaremos por WhatsApp.',
      ),
      'approved' => (
        Icons.verified_outlined,
        store.isFeatured
            ? 'Tu tienda está aprobada y destacada en el Inicio.'
            : 'Tu tienda está aprobada. Todo lo que publiques sale como tienda.',
      ),
      _ => (
        Icons.block,
        'Tu tienda está suspendida: sus productos no se muestran.',
      ),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 72,
              child: ClipOval(child: NetworkPicture(store.logoUrl)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: textTheme.titleLarge),
                  Text('${store.city} · +591 ${store.localWhatsapp}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(icon),
            title: Text(storeStatusLabels[store.status] ?? store.status),
            subtitle: Text(message),
          ),
        ),
        if (reviewNote != null) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.message_outlined),
              title: const Text('Nota del equipo'),
              subtitle: Text(reviewNote),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in store.deliveryOptions)
              Chip(label: Text(deliveryOptionLabels[option] ?? option)),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar datos y logo'),
        ),
        if (store.isApproved) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StoreScreen(storeSlug: store.slug),
              ),
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Ver mi tienda como cliente'),
          ),
        ],
      ],
    );
  }
}
