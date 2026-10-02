import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/error_retry.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'product_list_screen.dart';

const _categoryIcons = {
  'aviones-rc': Icons.flight,
  'helicopteros': Icons.air,
  'drones': Icons.videocam_outlined,
  'autos-rc': Icons.directions_car_outlined,
  'barcos': Icons.directions_boat_outlined,
  'trenes': Icons.train_outlined,
  'maquetas': Icons.construction_outlined,
  'die-cast': Icons.local_shipping_outlined,
  'radios-electronica': Icons.settings_remote_outlined,
  'baterias-cargadores': Icons.battery_charging_full,
  'pinturas-herramientas': Icons.format_paint_outlined,
  'accesorios': Icons.handyman_outlined,
};

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  late Future<List<Category>> _categories;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _categories = _load();
  }

  Future<List<Category>> _load() =>
      context.read<CatalogRepository>().categories();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: FutureBuilder(
        future: _categories,
        builder: (context, snapshot) {
          final categories = snapshot.data;
          if (categories != null) {
            return RefreshIndicator(
              onRefresh: () async {
                final reload = _load();
                setState(() {
                  _categories = reload;
                });
                await reload;
              },
              child: ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _CategoryTile(category: categories[index]),
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              message: errorMessageOf(snapshot.error),
              onRetry: () => setState(() {
                _categories = _load();
              }),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_categoryIcons[category.slug] ?? Icons.category_outlined),
      title: Text(category.name),
      trailing: Text(
        '${category.productCount}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductListScreen(
            title: category.name,
            filter: ProductFilter(categorySlug: category.slug),
          ),
        ),
      ),
    );
  }
}
