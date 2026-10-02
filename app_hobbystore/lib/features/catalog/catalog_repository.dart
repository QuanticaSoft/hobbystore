import '../../core/api/api_client.dart';
import 'catalog_models.dart';

class CatalogRepository {
  final ApiClient api;

  const CatalogRepository(this.api);

  Future<HomeData> home() async => HomeData.fromJson(await api.get('/home'));

  Future<List<Category>> categories() async {
    final data = await api.get('/categories');
    return (data['categories'] as List)
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ProductPage> products(ProductFilter filter, {int page = 1}) async =>
      ProductPage.fromJson(
        await api.get(
          '/products',
          query: {...filter.toQuery(), 'page': '$page'},
        ),
      );

  Future<ProductDetail> product(int id) async {
    final data = await api.get('/products/$id');
    return ProductDetail.fromJson(data['product'] as Map<String, dynamic>);
  }

  Future<StoreDetail> store(String slug) async {
    final data = await api.get('/stores/${Uri.encodeComponent(slug)}');
    return StoreDetail.fromJson(data['store'] as Map<String, dynamic>);
  }
}
