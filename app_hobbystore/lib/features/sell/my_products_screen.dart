import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format/price.dart';
import '../../core/widgets/coming_soon.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/network_picture.dart';
import 'my_product_models.dart';
import 'my_products_repository.dart';
import 'product_form_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  late Future<MyProductsPage> _page;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _page = _load();
  }

  Future<MyProductsPage> _load() => context.read<MyProductsRepository>().list();

  Future<void> _refresh() async {
    final reload = _load();
    setState(() {
      _page = reload;
    });
    await reload;
  }

  Future<void> _openForm([MyProduct? product]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(existing: product)),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _onAction(MyProduct product, String action) async {
    final repository = context.read<MyProductsRepository>();
    switch (action) {
      case 'edit':
        await _openForm(product);
      case 'delete':
        if (await _confirmDelete(product)) {
          await _run(() => repository.remove(product.id));
        }
      default:
        await _run(() => repository.setStatus(product.id, action));
    }
  }

  Future<bool> _confirmDelete(MyProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar "${product.title}"?'),
        content: const Text(
          'Deja de mostrarse y no se puede recuperar. Si solo quieres '
          'ocultarla por un tiempo, mejor pausarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis publicaciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Publicar'),
      ),
      body: FutureBuilder(
        future: _page,
        builder: (context, snapshot) {
          final page = snapshot.data;
          if (page != null && page.products.isEmpty) {
            return const ComingSoon(
              icon: Icons.sell_outlined,
              message:
                  'Aún no publicaste nada.\nToca "Publicar" para vender '
                  'un modelo, repuesto o accesorio.',
            );
          }
          if (page != null) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                // Espacio al final para que el botón flotante no tape la última.
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  _LimitBanner(page: page),
                  const SizedBox(height: 12),
                  for (final product in page.products)
                    _MyProductTile(
                      product: product,
                      onAction: (action) => _onAction(product, action),
                    ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              message: errorMessageOf(snapshot.error),
              onRetry: _refresh,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _LimitBanner extends StatelessWidget {
  final MyProductsPage page;

  const _LimitBanner({required this.page});

  @override
  Widget build(BuildContext context) {
    final limit = page.activeLimit;
    if (limit == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.storefront_outlined),
          title: Text('Publicas como tienda'),
          subtitle: Text('Sin límite de publicaciones activas.'),
        ),
      );
    }
    final atLimit = page.activeCount >= limit;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(atLimit ? Icons.info_outline : Icons.sell_outlined),
        title: Text('${page.activeCount} de $limit publicaciones activas'),
        subtitle: Text(
          atLimit
              ? 'Llegaste al máximo. Pausa o marca como vendida alguna para publicar otra.'
              : 'Como vendedor particular puedes tener hasta $limit activas. '
                    '¿Vendes seguido? Solicita tu tienda en Perfil.',
        ),
      ),
    );
  }
}

class _MyProductTile extends StatelessWidget {
  final MyProduct product;
  final ValueChanged<String> onAction;

  const _MyProductTile({required this.product, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cover = product.images.isEmpty ? null : product.images.first.thumbUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(dimension: 56, child: NetworkPicture(cover)),
        ),
        title: Text(
          product.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatBob(product.priceBob)} · '
          '${myProductStatusLabels[product.status] ?? product.status} · '
          '${product.stock} u.',
          style: textTheme.bodySmall,
        ),
        onTap: () => onAction('edit'),
        trailing: PopupMenuButton<String>(
          tooltip: 'Acciones',
          onSelected: onAction,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            if (product.status != 'active')
              const PopupMenuItem(value: 'active', child: Text('Publicar')),
            if (product.status == 'active')
              const PopupMenuItem(value: 'paused', child: Text('Pausar')),
            if (product.status != 'sold')
              const PopupMenuItem(value: 'sold', child: Text('Marcar vendida')),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}
