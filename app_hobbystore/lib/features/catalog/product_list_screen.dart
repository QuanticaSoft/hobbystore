import 'package:flutter/material.dart';

import 'catalog_models.dart';
import 'widgets/paged_product_grid.dart';

class ProductListScreen extends StatelessWidget {
  final String title;
  final ProductFilter filter;

  const ProductListScreen({
    super.key,
    required this.title,
    this.filter = const ProductFilter(),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PagedProductGrid(filter: filter),
    );
  }
}
