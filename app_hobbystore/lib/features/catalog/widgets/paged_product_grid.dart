import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../catalog_models.dart';
import '../catalog_repository.dart';
import 'product_card.dart';

/// Grilla de productos con scroll infinito y pull-to-refresh.
/// [header] se muestra arriba de la grilla (p. ej. los datos de una tienda).
class PagedProductGrid extends StatefulWidget {
  final ProductFilter filter;
  final Widget? header;
  final String emptyMessage;

  const PagedProductGrid({
    super.key,
    required this.filter,
    this.header,
    this.emptyMessage = 'No hay productos por aquí todavía.',
  });

  @override
  State<PagedProductGrid> createState() => _PagedProductGridState();
}

class _PagedProductGridState extends State<PagedProductGrid> {
  // Se pide la página siguiente cuando faltan menos de estos píxeles.
  static const _loadMoreThreshold = 600.0;

  final _products = <ProductSummary>[];
  int _nextPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await context.read<CatalogRepository>().products(
        widget.filter,
        page: _nextPage,
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(page.items);
        _hasMore = page.hasMore;
        _nextPage++;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _products.clear();
      _nextPage = 1;
      _hasMore = true;
    });
    await _loadMore();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < _loadMoreThreshold) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (header != null) SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid.builder(
                gridDelegate: productGridDelegate,
                itemCount: _products.length,
                itemBuilder: (_, index) =>
                    ProductCard(product: _products[index]),
              ),
            ),
            SliverToBoxAdapter(child: _footer()),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadMore,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(widget.emptyMessage, textAlign: TextAlign.center),
      );
    }
    return const SizedBox(height: 24);
  }
}
