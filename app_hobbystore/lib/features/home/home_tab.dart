import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/error_retry.dart';
import '../../core/widgets/network_picture.dart';
import '../catalog/catalog_models.dart';
import '../catalog/catalog_repository.dart';
import '../catalog/product_list_screen.dart';
import '../catalog/search_screen.dart';
import '../catalog/store_screen.dart';
import '../catalog/widgets/product_card.dart';
import '../session/user_session.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onCompleteProfile;

  const HomeTab({super.key, required this.onCompleteProfile});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<HomeData> _home;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _home = _load();
  }

  Future<HomeData> _load() => context.read<CatalogRepository>().home();

  Future<void> _refresh() async {
    final reload = _load();
    setState(() {
      _home = reload;
    });
    await reload;
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserSession>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Hobby Store')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder(
          future: _home,
          builder: (context, snapshot) {
            final home = snapshot.data;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SearchBar(
                      hintText: 'Buscar aviones, autos, maquetas...',
                      leading: const Icon(Icons.search),
                      elevation: const WidgetStatePropertyAll(1),
                      // Solo abre la pantalla de búsqueda; ahí se escribe.
                      readOnly: true,
                      onTap: () => _push(const SearchScreen()),
                    ),
                  ),
                ),
                if (user != null && !user.isProfileComplete)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.badge_outlined),
                          title: const Text('Completa tu perfil'),
                          subtitle: const Text(
                            'Tu nombre y ciudad ayudan a los vendedores a coordinar contigo.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onCompleteProfile,
                        ),
                      ),
                    ),
                  ),
                if (home != null)
                  ..._content(home)
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorRetry(
                      message: errorMessageOf(snapshot.error),
                      onRetry: _refresh,
                    ),
                  )
                else
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(HomeData home) => [
    if (home.banners.isNotEmpty)
      SliverToBoxAdapter(child: _BannerCarousel(banners: home.banners)),
    if (home.featuredStores.isNotEmpty) ...[
      const _SectionTitle('Tiendas'),
      SliverToBoxAdapter(
        child: _StoresRow(
          stores: home.featuredStores,
          onTap: (store) => _push(StoreScreen(storeSlug: store.slug)),
        ),
      ),
    ],
    _SectionTitle(
      'Novedades',
      actionLabel: 'Ver todo',
      onAction: () => _push(const ProductListScreen(title: 'Novedades')),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      sliver: SliverGrid.builder(
        gridDelegate: productGridDelegate,
        itemCount: home.latestProducts.length,
        itemBuilder: (_, index) =>
            ProductCard(product: home.latestProducts[index]),
      ),
    ),
  ];
}

class _BannerCarousel extends StatelessWidget {
  static const _height = 190.0;

  final List<HomeBanner> banners;

  const _BannerCarousel({required this.banners});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: CarouselView.weighted(
        flexWeights: const [1, 7, 1],
        itemSnapping: true,
        children: [
          for (final banner in banners)
            Stack(
              fit: StackFit.expand,
              children: [
                NetworkPicture(banner.imageUrl),
                // Degradado para que el título se lea sobre cualquier foto.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StoresRow extends StatelessWidget {
  final List<StoreSummary> stores;
  final ValueChanged<StoreSummary> onTap;

  const _StoresRow({required this.stores, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stores.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final store = stores[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(store),
            child: SizedBox(
              width: 80,
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 72,
                    child: ClipOval(child: NetworkPicture(store.logoUrl)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    store.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle(this.title, {this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
