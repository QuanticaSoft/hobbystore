class Category {
  final int id;
  final String slug;
  final String name;
  final int productCount;

  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.productCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as int,
    slug: json['slug'] as String,
    name: json['name'] as String,
    productCount: json['product_count'] as int,
  );
}

class StoreSummary {
  final String slug;
  final String name;
  final String city;
  final String? logoUrl;

  const StoreSummary({
    required this.slug,
    required this.name,
    required this.city,
    this.logoUrl,
  });

  factory StoreSummary.fromJson(Map<String, dynamic> json) => StoreSummary(
    slug: json['slug'] as String,
    name: json['name'] as String,
    city: json['city'] as String,
    logoUrl: json['logo_url'] as String?,
  );
}

class StoreDetail {
  final StoreSummary summary;
  final String? description;
  final List<String> deliveryOptions;
  final int productCount;

  const StoreDetail({
    required this.summary,
    this.description,
    this.deliveryOptions = const [],
    this.productCount = 0,
  });

  factory StoreDetail.fromJson(Map<String, dynamic> json) => StoreDetail(
    summary: StoreSummary.fromJson(json),
    description: json['description'] as String?,
    deliveryOptions: List<String>.from(json['delivery_options'] as List),
    productCount: json['product_count'] as int,
  );
}

class ProductSummary {
  final int id;
  final String title;
  final double priceBob;
  final String condition;
  final String city;
  final String? thumbUrl;
  final String sellerName;
  final String? storeSlug;

  const ProductSummary({
    required this.id,
    required this.title,
    required this.priceBob,
    required this.condition,
    required this.city,
    required this.sellerName,
    this.thumbUrl,
    this.storeSlug,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) => ProductSummary(
    id: json['id'] as int,
    title: json['title'] as String,
    priceBob: (json['price_bob'] as num).toDouble(),
    condition: json['condition'] as String,
    city: json['city'] as String,
    thumbUrl: json['thumb_url'] as String?,
    sellerName: json['seller_name'] as String,
    storeSlug: json['store_slug'] as String?,
  );

  bool get isUsed => condition == 'used';
}

class ProductImage {
  final String url;
  final String thumbUrl;

  const ProductImage({required this.url, required this.thumbUrl});

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    url: json['url'] as String,
    thumbUrl: json['thumb_url'] as String,
  );
}

class Seller {
  final bool isStore;
  final String name;
  final String? city;
  final String? storeSlug;
  final String? logoUrl;
  final List<String> deliveryOptions;

  const Seller({
    required this.isStore,
    required this.name,
    this.city,
    this.storeSlug,
    this.logoUrl,
    this.deliveryOptions = const [],
  });

  factory Seller.fromJson(Map<String, dynamic> json) => Seller(
    isStore: json['type'] == 'store',
    name: json['name'] as String,
    city: json['city'] as String?,
    storeSlug: json['store_slug'] as String?,
    logoUrl: json['logo_url'] as String?,
    deliveryOptions: List<String>.from(json['delivery_options'] as List),
  );
}

class ProductDetail {
  final int id;
  final String title;
  final String description;
  final double priceBob;
  final String condition;
  final int stock;
  final String city;
  final String categoryName;
  final List<ProductImage> images;
  final Seller seller;

  const ProductDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.priceBob,
    required this.condition,
    required this.stock,
    required this.city,
    required this.categoryName,
    required this.images,
    required this.seller,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
    priceBob: (json['price_bob'] as num).toDouble(),
    condition: json['condition'] as String,
    stock: json['stock'] as int,
    city: json['city'] as String,
    categoryName: (json['category'] as Map<String, dynamic>)['name'] as String,
    images: (json['images'] as List)
        .map((image) => ProductImage.fromJson(image as Map<String, dynamic>))
        .toList(),
    seller: Seller.fromJson(json['seller'] as Map<String, dynamic>),
  );

  bool get isUsed => condition == 'used';
}

class HomeBanner {
  final int id;
  final String title;
  final String? imageUrl;

  const HomeBanner({required this.id, required this.title, this.imageUrl});

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
    id: json['id'] as int,
    title: json['title'] as String,
    imageUrl: json['image_url'] as String?,
  );
}

class HomeData {
  final List<HomeBanner> banners;
  final List<StoreSummary> featuredStores;
  final List<ProductSummary> latestProducts;

  const HomeData({
    required this.banners,
    required this.featuredStores,
    required this.latestProducts,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
    banners: _list(json['banners'], HomeBanner.fromJson),
    featuredStores: _list(json['featured_stores'], StoreSummary.fromJson),
    latestProducts: _list(json['latest_products'], ProductSummary.fromJson),
  );
}

class ProductPage {
  final List<ProductSummary> items;
  final bool hasMore;

  const ProductPage({required this.items, required this.hasMore});

  factory ProductPage.fromJson(Map<String, dynamic> json) => ProductPage(
    items: _list(json['items'], ProductSummary.fromJson),
    hasMore: json['has_more'] as bool,
  );
}

/// Filtro de un listado de productos; todos opcionales.
class ProductFilter {
  final String? categorySlug;
  final String? storeSlug;
  final String? query;

  const ProductFilter({this.categorySlug, this.storeSlug, this.query});

  Map<String, String> toQuery() => {
    'category': ?categorySlug,
    'store': ?storeSlug,
    'q': ?query,
  };
}

const deliveryOptionLabels = {
  'pickup': 'Retiro en tienda',
  'local': 'Envío en la ciudad',
  'national': 'Envío nacional por encomienda',
};

List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) fromJson) =>
    (json as List)
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
