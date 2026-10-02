import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/photos/photo_picker.dart';
import '../../core/widgets/network_picture.dart';
import '../catalog/catalog_models.dart';
import 'my_store_models.dart';
import 'my_store_repository.dart';

/// Solicitar una tienda ([existing] null) o editar la propia. Devuelve `true`
/// al cerrar si hubo cambios.
class StoreFormScreen extends StatefulWidget {
  final MyStore? existing;

  const StoreFormScreen({super.key, this.existing});

  @override
  State<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends State<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _cityController = TextEditingController(
    text: widget.existing?.city,
  );
  late final _whatsappController = TextEditingController(
    text: widget.existing?.localWhatsapp,
  );
  late final _deliveryOptions = {...?widget.existing?.deliveryOptions};
  XFile? _newLogo;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await context.read<PhotoPicker>().pickFromGallery(max: 1);
    if (picked.isNotEmpty && mounted) setState(() => _newLogo = picked.first);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deliveryOptions.isEmpty) {
      setState(() => _errorMessage = 'Elige al menos una forma de entrega.');
      return;
    }

    final repository = context.read<MyStoreRepository>();
    final fields = StoreFields(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      city: _cityController.text.trim(),
      localWhatsapp: _whatsappController.text,
      // Mismo orden siempre, sin importar en cuál se tocó primero.
      deliveryOptions: deliveryOptionLabels.keys
          .where(_deliveryOptions.contains)
          .toList(),
    );
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      _isNew ? await repository.apply(fields) : await repository.update(fields);
      final logo = _newLogo;
      if (logo != null) await repository.uploadLogo(logo);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    final newLogo = _newLogo;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Quiero ser tienda' : 'Editar tienda'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isSaving ? null : _pickLogo,
                child: SizedBox.square(
                  dimension: 96,
                  child: ClipOval(
                    child: newLogo != null
                        ? FutureBuilder(
                            future: newLogo.readAsBytes(),
                            builder: (_, snapshot) => snapshot.hasData
                                ? Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  )
                                : const NetworkPicture(null),
                          )
                        : NetworkPicture(widget.existing?.logoUrl),
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _isSaving ? null : _pickLogo,
                child: const Text('Elegir logo'),
              ),
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la tienda',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              validator: (value) =>
                  (value ?? '').trim().length < 3 ? 'Mínimo 3 letras' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '¿Qué vendes?',
                hintText: 'Ej.: aviones RC, repuestos y taller de reparación',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Ciudad'),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp para pedidos',
                prefixText: '+591 ',
                helperText: 'Aquí te llegarán los pedidos de los compradores.',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              validator: (value) =>
                  RegExp(r'^\d{8}$').hasMatch(value ?? '') ? null : '8 dígitos',
            ),
            const SizedBox(height: 16),
            Text(
              'Formas de entrega',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in deliveryOptionLabels.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _deliveryOptions.contains(entry.key),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _deliveryOptions.add(entry.key)
                          : _deliveryOptions.remove(entry.key);
                    }),
                  ),
              ],
            ),
            if (_isNew) ...[
              const SizedBox(height: 16),
              Text(
                'Revisaremos tu solicitud. Cuando la aprobemos, tus '
                'publicaciones pasarán a tu tienda, podrás publicar sin '
                'límite y podremos destacarte en el Inicio.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isNew ? 'Enviar solicitud' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
