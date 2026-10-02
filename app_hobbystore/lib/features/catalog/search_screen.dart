import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import 'catalog_models.dart';
import 'widgets/paged_product_grid.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? _query;

  void _search(String text) {
    final query = text.trim();
    setState(() => _query = query.isEmpty ? null : query);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Buscar aviones, autos, maquetas...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: query == null
          ? const ComingSoon(
              icon: Icons.search,
              message: 'Escribe lo que buscas y presiona buscar.',
            )
          : PagedProductGrid(
              // Una búsqueda nueva reinicia la paginación.
              key: ValueKey(query),
              filter: ProductFilter(query: query),
              emptyMessage: 'Sin resultados para "$query".',
            ),
    );
  }
}
