import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import 'favorites_store.dart';

class FavoriteButton extends StatelessWidget {
  final int productId;

  /// Fondo blanco circular para leerse sobre fotos (tarjetas de producto).
  final bool onImage;

  const FavoriteButton({
    super.key,
    required this.productId,
    this.onImage = false,
  });

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FavoritesStore>().toggle(productId);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<FavoritesStore, bool>(
      (store) => store.isFavorite(productId),
    );
    final colors = Theme.of(context).colorScheme;

    final button = IconButton(
      tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? colors.primary : null,
      ),
      onPressed: () => _toggle(context),
    );
    if (!onImage) return button;

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: SizedBox.square(dimension: 40, child: button),
    );
  }
}
