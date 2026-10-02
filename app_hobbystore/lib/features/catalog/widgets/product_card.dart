import 'package:flutter/material.dart';

import '../../../core/format/price.dart';
import '../../../core/widgets/network_picture.dart';
import '../../favorites/favorite_button.dart';
import '../catalog_models.dart';
import '../product_detail_screen.dart';

/// Grilla de 2 columnas; la proporción deja una foto casi cuadrada + 3 líneas.
const productGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 0.64,
);

class ProductCard extends StatelessWidget {
  final ProductSummary product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: product.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La foto toma el alto que sobra: así el texto nunca desborda
            // la tarjeta, sea cual sea el ancho de la pantalla.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.white,
                    child: NetworkPicture(
                      product.thumbUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (product.isUsed)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(label: 'Usado'),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: FavoriteButton(productId: product.id, onImage: true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Text(
                formatBob(product.priceBob),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: Text(
                '${product.sellerName} · ${product.city}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: colors.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onTertiaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
