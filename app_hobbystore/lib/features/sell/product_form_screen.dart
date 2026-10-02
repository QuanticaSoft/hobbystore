import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/photos/photo_picker.dart';
import '../../core/widgets/network_picture.dart';
import '../catalog/catalog_models.dart';
import '../catalog/catalog_repository.dart';
import 'my_product_models.dart';
import 'my_products_repository.dart';

final _thousandsWithDots = RegExp(r'^\d{1,3}(\.\d{3})+$');

/// Acepta "1250", "1250,50" y "12.5". El punto se toma como separador de
/// miles solo con forma de miles ("1.250", "12.500"); la coma, como decimal.
double? parsePrice(String text) {
  var normalized = text.trim();
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else if (_thousandsWithDots.hasMatch(normalized)) {
    normalized = normalized.replaceAll('.', '');
  }
  return double.tryParse(normalized);
}

/// Publicar un producto nuevo o editar uno propio.
///
/// Alta: se crea pausado → se suben las fotos → se activa. Si algo falla a
/// mitad de camino, la publicación ya existe (pausada) y "Publicar" reintenta
/// solo lo que faltó. Devuelve `true` al cerrar si hubo cambios.
class ProductFormScreen extends StatefulWidget {
  final MyProduct? existing;

  const ProductFormScreen({super.key, this.existing});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _maxPhotos = 5;

  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.existing?.title,
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _priceController = TextEditingController(
    text: widget.existing == null
        ? null
        : _priceText(widget.existing!.priceBob),
  );
  late final _stockController = TextEditingController(
    text: '${widget.existing?.stock ?? 1}',
  );
  late String? _categorySlug = widget.existing?.categorySlug;
  late String _condition = widget.existing?.condition ?? 'used';

  /// Publicación guardada en el servidor (la existente o la recién creada).
  late MyProduct? _saved = widget.existing;

  /// Fotos elegidas que todavía no se subieron.
  final _pendingPhotos = <XFile>[];

  late Future<List<Category>> _categories;
  bool _isSaving = false;
  String? _progress;
  String? _errorMessage;
  bool _changed = false;

  bool get _isNew => widget.existing == null;
  int get _photoCount => (_saved?.images.length ?? 0) + _pendingPhotos.length;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _categories = context.read<CatalogRepository>().categories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  static String _priceText(double price) => price == price.roundToDouble()
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2).replaceAll('.', ',');

  Future<void> _addPhotos({required bool fromCamera}) async {
    final picker = context.read<PhotoPicker>();
    final free = _maxPhotos - _photoCount;
    final picked = fromCamera
        ? [?await picker.takePhoto()]
        : await picker.pickFromGallery(max: free);
    if (picked.isEmpty || !mounted) return;
    setState(() => _pendingPhotos.addAll(picked.take(free)));
  }

  Future<void> _deleteSavedPhoto(MyProductImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Quitar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await context.read<MyProductsRepository>().deletePhoto(
        _saved!.id,
        image.id,
      );
      setState(() {
        _saved = updated;
        _changed = true;
      });
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoCount == 0) {
      setState(() => _errorMessage = 'Agrega al menos una foto.');
      return;
    }

    final repository = context.read<MyProductsRepository>();
    final fields = ProductFields(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      categorySlug: _categorySlug!,
      priceBob: parsePrice(_priceController.text)!,
      condition: _condition,
      stock: int.parse(_stockController.text),
    );
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      var product = _saved == null
          ? await repository.create(fields)
          : await repository.update(_saved!.id, fields);
      _saved = product;
      _changed = true;

      final total = _pendingPhotos.length;
      for (var i = 0; _pendingPhotos.isNotEmpty; i++) {
        setState(() => _progress = 'Subiendo foto ${i + 1} de $total...');
        product = await repository.addPhoto(product.id, _pendingPhotos.first);
        setState(() {
          _saved = product;
          _pendingPhotos.removeAt(0);
        });
      }

      // Una publicación nueva (o que quedó pausada en un intento anterior) se
      // activa al final; al editar una existente se respeta su estado.
      if (_isNew && !product.isActive) {
        setState(() => _progress = 'Publicando...');
        product = await repository.setStatus(product.id, 'active');
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _saved != null && _isNew
            ? '${e.message}\nTu publicación quedó guardada como pausada.'
            : e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;

    return PopScope(
      // Toda salida (flecha o gesto) pasa por aquí: así se informa a la lista
      // si hubo cambios, y no se puede salir a mitad de una subida.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Publicar producto' : 'Editar publicación'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Fotos ($_photoCount de $_maxPhotos)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _photosRow(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                validator: (value) => (value ?? '').trim().length < 3
                    ? 'Escribe un título (mínimo 3 letras)'
                    : null,
              ),
              const SizedBox(height: 8),
              FutureBuilder(
                future: _categories,
                builder: (context, snapshot) => DropdownButtonFormField<String>(
                  initialValue: _categorySlug,
                  // Sin esto, un nombre largo desborda en pantallas angostas.
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final category in snapshot.data ?? <Category>[])
                      DropdownMenuItem(
                        value: category.slug,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (slug) => setState(() => _categorySlug = slug),
                  validator: (slug) =>
                      slug == null ? 'Elige una categoría' : null,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio',
                        prefixText: 'Bs ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: (value) {
                        final price = parsePrice(value ?? '');
                        return price == null || price <= 0
                            ? 'Precio inválido'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(labelText: 'Unidades'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final stock = int.tryParse(value ?? '');
                        return stock == null || stock > 999
                            ? 'Entre 0 y 999'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'new', label: Text('Nuevo')),
                  ButtonSegment(value: 'used', label: Text('Usado')),
                ],
                selected: {_condition},
                onSelectionChanged: (selection) =>
                    setState(() => _condition = selection.single),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Estado, qué incluye, detalles importantes...',
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 5,
                minLines: 3,
                maxLength: 2000,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(
                  _progress ?? (_isNew ? 'Publicar' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photosRow() {
    final saved = _saved?.images ?? const <MyProductImage>[];
    final canAdd = _photoCount < _maxPhotos && !_isSaving;

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final image in saved)
            _PhotoTile(
              image: NetworkPicture(image.thumbUrl),
              onRemove: _isSaving ? null : () => _deleteSavedPhoto(image),
            ),
          for (final photo in _pendingPhotos)
            _PhotoTile(
              image: FutureBuilder(
                future: photo.readAsBytes(),
                builder: (_, snapshot) => snapshot.hasData
                    ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                    : const NetworkPicture(null),
              ),
              onRemove: _isSaving
                  ? null
                  : () => setState(() => _pendingPhotos.remove(photo)),
            ),
          if (canAdd) ...[
            _AddPhotoTile(
              icon: Icons.photo_library_outlined,
              label: 'Galería',
              onTap: () => _addPhotos(fromCamera: false),
            ),
            _AddPhotoTile(
              icon: Icons.photo_camera_outlined,
              label: 'Cámara',
              onTap: () => _addPhotos(fromCamera: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Widget image;
  final VoidCallback? onRemove;

  const _PhotoTile({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox.square(
        dimension: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddPhotoTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
