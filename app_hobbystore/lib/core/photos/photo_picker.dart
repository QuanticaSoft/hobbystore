import 'package:image_picker/image_picker.dart';

/// Elige o toma fotos de producto. Inyectable para que los tests no dependan
/// del plugin nativo.
class PhotoPicker {
  // Las fotos se reducen en el teléfono antes de subirlas: menos datos móviles
  // y muy por debajo del límite del servidor (8 MB).
  static const _maxSide = 1600.0;
  static const _quality = 80;

  final ImagePicker _picker;

  PhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  /// Hasta [max] fotos de la galería. requestFullMetadata en false evita
  /// pedir acceso completo a la fototeca en iOS.
  Future<List<XFile>> pickFromGallery({required int max}) async {
    if (max <= 0) return [];
    // pickMultiImage exige limit >= 2: para una sola foto se usa pickImage.
    if (max == 1) {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        requestFullMetadata: false,
      );
      return [?photo];
    }
    final photos = await _picker.pickMultiImage(
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
      limit: max,
      requestFullMetadata: false,
    );
    // En Android 12 o anterior el límite no siempre se respeta.
    return photos.take(max).toList();
  }

  Future<XFile?> takePhoto() => _picker.pickImage(
    source: ImageSource.camera,
    maxWidth: _maxSide,
    maxHeight: _maxSide,
    imageQuality: _quality,
    requestFullMetadata: false,
  );
}
