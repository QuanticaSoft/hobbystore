import '../catalog/catalog_models.dart';

class CartItem {
  final ProductSummary product;
  final int qty;
  final int stock;
  final double lineTotalBob;

  const CartItem({
    required this.product,
    required this.qty,
    required this.stock,
    required this.lineTotalBob,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: ProductSummary.fromJson(json),
    qty: json['qty'] as int,
    stock: json['stock'] as int,
    lineTotalBob: (json['line_total_bob'] as num).toDouble(),
  );
}

class CartSeller {
  final bool isStore;
  final String name;
  final String? storeSlug;
  final String city;

  const CartSeller({
    required this.isStore,
    required this.name,
    required this.city,
    this.storeSlug,
  });

  factory CartSeller.fromJson(Map<String, dynamic> json) => CartSeller(
    isStore: json['type'] == 'store',
    name: json['name'] as String,
    storeSlug: json['store_slug'] as String?,
    city: json['city'] as String,
  );
}

/// Los productos de un mismo vendedor: será un pedido por WhatsApp (Fase 4).
class CartGroup {
  /// Identifica al vendedor al crear el pedido (`store:<slug>` o `user:<id>`).
  final String key;
  final CartSeller seller;
  final List<CartItem> items;
  final double subtotalBob;

  const CartGroup({
    required this.key,
    required this.seller,
    required this.items,
    required this.subtotalBob,
  });

  factory CartGroup.fromJson(Map<String, dynamic> json) => CartGroup(
    key: json['key'] as String,
    seller: CartSeller.fromJson(json['seller'] as Map<String, dynamic>),
    items: (json['items'] as List)
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    subtotalBob: (json['subtotal_bob'] as num).toDouble(),
  );
}

class Cart {
  final List<CartGroup> groups;
  final int itemCount;
  final double totalBob;

  const Cart({
    required this.groups,
    required this.itemCount,
    required this.totalBob,
  });

  static const empty = Cart(groups: [], itemCount: 0, totalBob: 0);

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
    groups: (json['groups'] as List)
        .map((group) => CartGroup.fromJson(group as Map<String, dynamic>))
        .toList(),
    itemCount: json['item_count'] as int,
    totalBob: (json['total_bob'] as num).toDouble(),
  );

  int quantityOf(int productId) {
    for (final group in groups) {
      for (final item in group.items) {
        if (item.product.id == productId) return item.qty;
      }
    }
    return 0;
  }
}
