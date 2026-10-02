import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../store/my_store_models.dart';

class AdminStore {
  final MyStore store;
  final String? ownerName;
  final String ownerPhone;
  final int productCount;

  const AdminStore({
    required this.store,
    required this.ownerPhone,
    required this.productCount,
    this.ownerName,
  });

  factory AdminStore.fromJson(Map<String, dynamic> json) => AdminStore(
    store: MyStore.fromJson(json),
    ownerName: json['owner_name'] as String?,
    ownerPhone: json['owner_phone'] as String,
    productCount: json['product_count'] as int,
  );
}

class AdminBanner {
  final int id;
  final String title;
  final String? imageUrl;
  final bool active;

  const AdminBanner({
    required this.id,
    required this.title,
    required this.active,
    this.imageUrl,
  });

  factory AdminBanner.fromJson(Map<String, dynamic> json) => AdminBanner(
    id: json['id'] as int,
    title: json['title'] as String,
    imageUrl: json['image_url'] as String?,
    active: json['active'] as bool,
  );
}

class AdminRepository {
  final ApiClient api;

  const AdminRepository(this.api);

  Future<List<AdminStore>> stores(String status) async {
    final data = await api.get('/admin/stores', query: {'status': status});
    return (data['stores'] as List)
        .map((json) => AdminStore.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// [changes]: status (approved | suspended), is_featured, review_note.
  Future<void> updateStore(String slug, Map<String, dynamic> changes) =>
      api.patch('/admin/stores/${Uri.encodeComponent(slug)}', changes);

  Future<List<AdminBanner>> banners() async {
    final data = await api.get('/admin/banners');
    return (data['banners'] as List)
        .map((json) => AdminBanner.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createBanner(String title, XFile image) async => api.upload(
    '/admin/banners',
    field: 'photo',
    bytes: await image.readAsBytes(),
    filename: image.name,
    fields: {'title': title},
  );

  Future<void> setBannerActive(int id, {required bool active}) =>
      api.patch('/admin/banners/$id', {'active': active});

  Future<void> deleteBanner(int id) => api.delete('/admin/banners/$id');

  Future<void> removeProduct(int id) => api.delete('/admin/products/$id');
}
