const myProductStatusLabels = {
  'active': 'Publicada',
  'paused': 'Pausada',
  'sold': 'Vendida',
};

class MyProductImage {
  final int id;
  final String url;
  final String thumbUrl;

  const MyProductImage({
    required this.id,
    required this.url,
    required this.thumbUrl,
  });

  factory MyProductImage.fromJson(Map<String, dynamic> json) => MyProductImage(
    id: json['id'] as int,
    url: json['url'] as String,
    thumbUrl: json['thumb_url'] as String,
  );
}

/// Una publicación propia, con todos los campos editables.
class MyProduct {
  final int id;
  final String title;
  final String description;
  final double priceBob;
  final String condition;
  final int stock;
  final String status;
  final String categorySlug;
  final String categoryName;
  final List<MyProductImage> images;

  const MyProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.priceBob,
    required this.condition,
    required this.stock,
    required this.status,
    required this.categorySlug,
    required this.categoryName,
    required this.images,
  });

  factory MyProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>;
    return MyProduct(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      priceBob: (json['price_bob'] as num).toDouble(),
      condition: json['condition'] as String,
      stock: json['stock'] as int,
      status: json['status'] as String,
      categorySlug: category['slug'] as String,
      categoryName: category['name'] as String,
      images: (json['images'] as List)
          .map(
            (image) => MyProductImage.fromJson(image as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  bool get isActive => status == 'active';
}

class MyProductsPage {
  final List<MyProduct> products;
  final int activeCount;

  /// null: publica como tienda, sin tope.
  final int? activeLimit;

  const MyProductsPage({
    required this.products,
    required this.activeCount,
    required this.activeLimit,
  });

  factory MyProductsPage.fromJson(Map<String, dynamic> json) => MyProductsPage(
    products: (json['products'] as List)
        .map((product) => MyProduct.fromJson(product as Map<String, dynamic>))
        .toList(),
    activeCount: json['active_count'] as int,
    activeLimit: json['active_limit'] as int?,
  );
}

/// Campos del formulario de publicación, tal como los espera la API.
class ProductFields {
  final String title;
  final String description;
  final String categorySlug;
  final double priceBob;
  final String condition;
  final int stock;

  const ProductFields({
    required this.title,
    required this.description,
    required this.categorySlug,
    required this.priceBob,
    required this.condition,
    required this.stock,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': categorySlug,
    'price_bob': priceBob,
    'condition': condition,
    'stock': stock,
  };
}
