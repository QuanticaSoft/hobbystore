import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import 'my_product_models.dart';

class MyProductsRepository {
  final ApiClient api;

  const MyProductsRepository(this.api);

  Future<MyProductsPage> list() async =>
      MyProductsPage.fromJson(await api.get('/my/products'));

  /// Se crea pausada: se activa después de subir las fotos.
  Future<MyProduct> create(ProductFields fields) async =>
      _product(await api.post('/my/products', fields.toJson()));

  Future<MyProduct> update(int id, ProductFields fields) async =>
      _product(await api.patch('/my/products/$id', fields.toJson()));

  Future<MyProduct> setStatus(int id, String status) async =>
      _product(await api.patch('/my/products/$id', {'status': status}));

  Future<void> remove(int id) => api.delete('/my/products/$id');

  Future<MyProduct> addPhoto(int id, XFile photo) async => _product(
    await api.upload(
      '/my/products/$id/images',
      field: 'photo',
      bytes: await photo.readAsBytes(),
      filename: photo.name,
    ),
  );

  Future<MyProduct> deletePhoto(int id, int imageId) async =>
      _product(await api.delete('/my/products/$id/images/$imageId'));

  MyProduct _product(Map<String, dynamic> data) =>
      MyProduct.fromJson(data['product'] as Map<String, dynamic>);
}
