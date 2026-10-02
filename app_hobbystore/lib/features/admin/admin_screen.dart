import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/links/external_links.dart';
import '../../core/photos/photo_picker.dart';
import '../../core/widgets/coming_soon.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/network_picture.dart';
import '../../core/widgets/text_input_dialog.dart';
import 'admin_repository.dart';

/// Moderación de tiendas y banners. Solo se muestra a usuarios is_admin; la
/// API igual rechaza (403) a cualquier otro.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tiendas'),
              Tab(text: 'Banners'),
            ],
          ),
        ),
        body: const TabBarView(children: [_StoresTab(), _BannersTab()]),
      ),
    );
  }
}

/// Muestra el error de una acción del admin sin romper la pantalla.
Future<bool> _runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

class _StoresTab extends StatefulWidget {
  const _StoresTab();

  @override
  State<_StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends State<_StoresTab> {
  String _status = 'pending';
  late Future<List<AdminStore>> _stores;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _stores = _load();
  }

  Future<List<AdminStore>> _load() =>
      context.read<AdminRepository>().stores(_status);

  void _reload() => setState(() {
    _stores = _load();
  });

  Future<void> _update(AdminStore item, Map<String, dynamic> changes) async {
    final repository = context.read<AdminRepository>();
    if (await _runAction(
      context,
      () => repository.updateStore(item.store.slug, changes),
    )) {
      _reload();
    }
  }

  Future<void> _suspend(AdminStore item) async {
    final note = await showTextInputDialog(
      context,
      title: 'Suspender "${item.store.name}"',
      label: 'Motivo (lo verá el dueño)',
      confirmLabel: 'Suspender',
      maxLines: 3,
    );
    if (note == null) return;
    await _update(item, {
      'status': 'suspended',
      'review_note': note.isEmpty ? null : note,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pendientes')),
              ButtonSegment(value: 'approved', label: Text('Aprobadas')),
              ButtonSegment(value: 'suspended', label: Text('Suspendidas')),
            ],
            selected: {_status},
            onSelectionChanged: (selection) {
              _status = selection.single;
              _reload();
            },
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _stores,
            builder: (context, snapshot) {
              final stores = snapshot.data;
              if (stores != null && stores.isEmpty) {
                return const ComingSoon(
                  icon: Icons.storefront_outlined,
                  message: 'No hay tiendas en este estado.',
                );
              }
              if (stores != null) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    for (final item in stores)
                      _AdminStoreCard(
                        item: item,
                        onApprove: () => _update(item, {
                          'status': 'approved',
                          'review_note': null,
                        }),
                        onSuspend: () => _suspend(item),
                        onFeatured: (featured) =>
                            _update(item, {'is_featured': featured}),
                      ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ErrorRetry(
                  message: errorMessageOf(snapshot.error),
                  onRetry: _reload,
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ],
    );
  }
}

class _AdminStoreCard extends StatelessWidget {
  final AdminStore item;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;
  final ValueChanged<bool> onFeatured;

  const _AdminStoreCard({
    required this.item,
    required this.onApprove,
    required this.onSuspend,
    required this.onFeatured,
  });

  @override
  Widget build(BuildContext context) {
    final store = item.store;
    final textTheme = Theme.of(context).textTheme;
    final description = store.description;
    final reviewNote = store.reviewNote;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: ClipOval(child: NetworkPicture(store.logoUrl)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name, style: textTheme.titleMedium),
                      Text(
                        '${store.city} · ${item.productCount} productos activos',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dueño: ${item.ownerName ?? 'sin nombre'} (${item.ownerPhone})',
            ),
            Text('WhatsApp de la tienda: ${store.whatsappPhone}'),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(description, style: textTheme.bodySmall),
            ],
            if (reviewNote != null) ...[
              const SizedBox(height: 4),
              Text('Nota: $reviewNote', style: textTheme.bodySmall),
            ],
            if (store.isApproved)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Destacada en el Inicio'),
                value: store.isFeatured,
                onChanged: onFeatured,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.read<ExternalLinks>().open(
                    Uri.parse(
                      'https://wa.me/${item.ownerPhone.replaceFirst('+', '')}',
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp al dueño'),
                ),
                if (!store.isApproved)
                  FilledButton(
                    onPressed: onApprove,
                    child: Text(
                      store.status == 'pending' ? 'Aprobar' : 'Reactivar',
                    ),
                  ),
                if (store.status != 'suspended')
                  TextButton(
                    onPressed: onSuspend,
                    child: Text(
                      store.status == 'pending' ? 'Rechazar' : 'Suspender',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannersTab extends StatefulWidget {
  const _BannersTab();

  @override
  State<_BannersTab> createState() => _BannersTabState();
}

class _BannersTabState extends State<_BannersTab> {
  late Future<List<AdminBanner>> _banners;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _banners = context.read<AdminRepository>().banners();
  }

  void _reload() => setState(() {
    _banners = context.read<AdminRepository>().banners();
  });

  Future<void> _create() async {
    final repository = context.read<AdminRepository>();
    final picked = await context.read<PhotoPicker>().pickFromGallery(max: 1);
    if (picked.isEmpty || !mounted) return;

    final title = await showTextInputDialog(
      context,
      title: 'Nuevo banner',
      label: 'Título',
      hint: 'Ej.: Festival de aeromodelismo · 15 de noviembre',
      confirmLabel: 'Publicar',
      maxLength: 120,
    );
    if (title == null || title.isEmpty || !mounted) return;

    if (await _runAction(
      context,
      () => repository.createBanner(title, picked.first),
    )) {
      _reload();
    }
  }

  Future<void> _delete(AdminBanner banner) async {
    final repository = context.read<AdminRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Borrar "${banner.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await _runAction(context, () => repository.deleteBanner(banner.id))) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AdminRepository>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Nuevo banner'),
      ),
      body: FutureBuilder(
        future: _banners,
        builder: (context, snapshot) {
          final banners = snapshot.data;
          if (banners != null && banners.isEmpty) {
            return const ComingSoon(
              icon: Icons.view_carousel_outlined,
              message: 'Sin banners. Agrega eventos, festivales o avisos.',
            );
          }
          if (banners != null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                for (final banner in banners)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 2,
                          child: NetworkPicture(banner.imageUrl),
                        ),
                        SwitchListTile(
                          title: Text(banner.title),
                          subtitle: Text(
                            banner.active ? 'Visible en el Inicio' : 'Oculto',
                          ),
                          value: banner.active,
                          onChanged: (active) async {
                            if (await _runAction(
                              context,
                              () => repository.setBannerActive(
                                banner.id,
                                active: active,
                              ),
                            )) {
                              _reload();
                            }
                          },
                          secondary: IconButton(
                            tooltip: 'Borrar banner',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(banner),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              message: errorMessageOf(snapshot.error),
              onRetry: _reload,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
