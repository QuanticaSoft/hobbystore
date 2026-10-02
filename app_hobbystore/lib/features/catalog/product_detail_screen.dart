import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format/price.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/network_picture.dart';
import '../cart/add_to_cart_button.dart';
import '../favorites/favorite_button.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'store_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ProductDetail> _product;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _product = _load();
  }

  Future<ProductDetail> _load() =>
      context.read<CatalogRepository>().product(widget.productId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _product,
      builder: (context, snapshot) {
        final product = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            actions: [
              if (product != null) FavoriteButton(productId: product.id),
            ],
          ),
          body: product != null
              ? _ProductBody(product: product)
              : snapshot.hasError
              ? ErrorRetry(
                  message: errorMessageOf(snapshot.error),
                  onRetry: () => setState(() {
                    _product = _load();
                  }),
                )
              : const Center(child: CircularProgressIndicator()),
          bottomNavigationBar: product == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: AddToCartButton(
                      productId: product.id,
                      stock: product.stock,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _ProductBody extends StatelessWidget {
  final ProductDetail product;

  const _ProductBody({required this.product});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return ListView(
      children: [
        _Gallery(images: product.images),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatBob(product.priceBob),
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(product.title, style: textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(product.isUsed ? 'Usado' : 'Nuevo')),
                  Chip(label: Text(product.categoryName)),
                  Chip(
                    avatar: const Icon(Icons.place_outlined, size: 18),
                    label: Text(product.city),
                  ),
                  if (!product.isUsed)
                    Chip(label: Text('Stock: ${product.stock}')),
                ],
              ),
              const SizedBox(height: 16),
              _SellerCard(seller: product.seller),
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Descripción', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(product.description, style: textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  final List<ProductImage> images;

  const _Gallery({required this.images});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final colors = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 1,
      child: ColoredBox(
        color: Colors.white,
        child: images.isEmpty
            ? const NetworkPicture(null)
            : Stack(
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (index) => setState(() => _current = index),
                    itemBuilder: (_, index) =>
                        NetworkPicture(images[index].url, fit: BoxFit.contain),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < images.length; i++)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _current
                                    ? colors.primary
                                    : colors.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final Seller seller;

  const _SellerCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    final storeSlug = seller.storeSlug;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: seller.logoUrl == null
                  ? const Icon(Icons.person_outline)
                  : ClipOval(child: NetworkPicture(seller.logoUrl)),
            ),
            title: Text(seller.name),
            subtitle: Text(
              [
                seller.isStore ? 'Tienda' : 'Vendedor particular',
                ?seller.city,
              ].join(' · '),
            ),
            trailing: storeSlug == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: storeSlug == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoreScreen(storeSlug: storeSlug),
                    ),
                  ),
          ),
          if (seller.deliveryOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entrega', style: textTheme.labelLarge),
                  const SizedBox(height: 4),
                  for (final option in seller.deliveryOptions)
                    Text('• ${deliveryOptionLabels[option] ?? option}'),
                ],
              ),
            )
          else if (!seller.isStore)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('La entrega se coordina con el vendedor.'),
            ),
        ],
      ),
    );
  }
}
