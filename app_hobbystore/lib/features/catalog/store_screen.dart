import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/error_retry.dart';
import '../../core/widgets/network_picture.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'widgets/paged_product_grid.dart';

class StoreScreen extends StatefulWidget {
  final String storeSlug;

  const StoreScreen({super.key, required this.storeSlug});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<StoreDetail> _store;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _store = _load();
  }

  Future<StoreDetail> _load() =>
      context.read<CatalogRepository>().store(widget.storeSlug);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _store,
      builder: (context, snapshot) {
        final store = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(store?.summary.name ?? '')),
          body: store != null
              ? PagedProductGrid(
                  filter: ProductFilter(storeSlug: widget.storeSlug),
                  header: _StoreHeader(store: store),
                  emptyMessage: 'Esta tienda aún no publicó productos.',
                )
              : snapshot.hasError
              ? ErrorRetry(
                  message: errorMessageOf(snapshot.error),
                  onRetry: () => setState(() {
                    _store = _load();
                  }),
                )
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final StoreDetail store;

  const _StoreHeader({required this.store});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = store.description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 72,
                child: ClipOval(child: NetworkPicture(store.summary.logoUrl)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.summary.name, style: textTheme.titleLarge),
                    Text(
                      '${store.summary.city} · ${store.productCount} productos',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: textTheme.bodyLarge),
          ],
          if (store.deliveryOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in store.deliveryOptions)
                  Chip(
                    avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(deliveryOptionLabels[option] ?? option),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
