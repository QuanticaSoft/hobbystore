import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import 'cart_store.dart';

class AddToCartButton extends StatelessWidget {
  final int productId;
  final int stock;

  const AddToCartButton({
    super.key,
    required this.productId,
    required this.stock,
  });

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<CartStore>().add(productId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Añadido al carrito.')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    final inCart = cart.cart.quantityOf(productId);
    final isBusy = cart.isBusy(productId);

    if (stock == 0) {
      return const FilledButton(onPressed: null, child: Text('Sin stock'));
    }
    return FilledButton.icon(
      onPressed: isBusy || inCart >= stock ? null : () => _add(context),
      icon: const Icon(Icons.add_shopping_cart),
      label: Text(
        inCart == 0
            ? 'Añadir al carrito'
            : 'Añadir otro ($inCart en el carrito)',
      ),
    );
  }
}
