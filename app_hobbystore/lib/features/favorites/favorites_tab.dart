import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/coming_soon.dart';
import '../../core/widgets/error_retry.dart';
import '../catalog/widgets/product_card.dart';
import 'favorites_store.dart';

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FavoritesStore>();
    final items = store.items;
    final errorMessage = store.errorMessage;

    final Widget body;
    if (items.isNotEmpty) {
      body = RefreshIndicator(
        onRefresh: store.load,
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: productGridDelegate,
          itemCount: items.length,
          itemBuilder: (_, index) => ProductCard(product: items[index]),
        ),
      );
    } else if (store.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (errorMessage != null) {
      body = ErrorRetry(message: errorMessage, onRetry: store.load);
    } else {
      body = const ComingSoon(
        icon: Icons.favorite_outline,
        message: 'Toca el ♥ de un producto para guardarlo aquí.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: body,
    );
  }
}
