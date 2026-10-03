import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import 'my_store_models.dart';

class MyStoreRepository {
  final ApiClient api;

  const MyStoreRepository(this.api);

  /// null si el usuario todavía no solicitó una tienda.
  Future<MyStore?> get() async {
    final data = await api.get('/my/store');
    final store = data['store'];
    return store == null
        ? null
        : MyStore.fromJson(store as Map<String, dynamic>);
  }

  /// La solicitud queda "en revisión" hasta que el admin la aprueba.
  Future<MyStore> apply(StoreFields fields) async =>
      _store(await api.post('/my/store', fields.toJson()));

  Future<MyStore> update(StoreFields fields) async =>
      _store(await api.patch('/my/store', fields.toJson()));

  Future<MyStore> uploadLogo(XFile photo) async => _store(
    await api.upload(
      '/my/store/logo',
      field: 'photo',
      bytes: await photo.readAsBytes(),
      filename: photo.name,
    ),
  );

  MyStore _store(Map<String, dynamic> data) =>
      MyStore.fromJson(data['store'] as Map<String, dynamic>);
}
