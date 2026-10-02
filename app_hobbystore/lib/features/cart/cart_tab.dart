import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format/price.dart';
import '../../core/widgets/coming_soon.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/network_picture.dart';
import '../catalog/product_detail_screen.dart';
import 'cart_models.dart';
import 'cart_store.dart';

class CartTab extends StatelessWidget {
  const CartTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CartStore>();
    final cart = store.cart;
    final errorMessage = store.errorMessage;

    final Widget body;
    if (cart.groups.isNotEmpty) {
      body = RefreshIndicator(
        onRefresh: store.load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final group in cart.groups) ...[
              _GroupCard(group: group),
              const SizedBox(height: 12),
            ],
            Text(
              '${cart.itemCount} producto(s) · ${cart.groups.length} vendedor(es)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    } else if (store.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (errorMessage != null) {
      body = ErrorRetry(message: errorMessage, onRetry: store.load);
    } else {
      body = const ComingSoon(
        icon: Icons.shopping_cart_outlined,
        message:
            'Tu carrito está vacío.\nLos productos se agrupan por vendedor '
            'para pedirlos por WhatsApp.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Carrito')),
      body: body,
    );
  }
}

class _GroupCard extends StatelessWidget {
  final CartGroup group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final seller = group.seller;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(
                seller.isStore
                    ? Icons.storefront_outlined
                    : Icons.person_outline,
              ),
              title: Text(seller.name, style: textTheme.titleMedium),
              subtitle: Text(
                '${seller.isStore ? 'Tienda' : 'Vendedor particular'} · ${seller.city}',
              ),
            ),
            const Divider(height: 1),
            for (final item in group.items) _ItemRow(item: item),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Subtotal', style: textTheme.titleMedium),
                  ),
                  Text(
                    formatBob(group.subtotalBob),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // El pedido por WhatsApp llega en la Fase 4.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.chat_outlined),
                label: Text('Pedir a ${seller.name} (muy pronto)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final CartItem item;

  const _ItemRow({required this.item});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() change,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await change();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CartStore>();
    final product = item.product;
    final isBusy = store.isBusy(product.id);
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: product.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 56,
                child: ColoredBox(
                  color: Colors.white,
                  child: NetworkPicture(product.thumbUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.qty > 1
                        ? '${formatBob(product.priceBob)} c/u · ${formatBob(item.lineTotalBob)}'
                        : formatBob(item.lineTotalBob),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: item.qty == 1 ? 'Quitar' : 'Uno menos',
              icon: Icon(item.qty == 1 ? Icons.delete_outline : Icons.remove),
              onPressed: isBusy
                  ? null
                  : () => _run(
                      context,
                      () => item.qty == 1
                          ? store.remove(product.id)
                          : store.setQuantity(product.id, item.qty - 1),
                    ),
            ),
            Text('${item.qty}', style: textTheme.titleMedium),
            IconButton(
              tooltip: 'Uno más',
              icon: const Icon(Icons.add),
              onPressed: isBusy || item.qty >= item.stock
                  ? null
                  : () => _run(
                      context,
                      () => store.setQuantity(product.id, item.qty + 1),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
