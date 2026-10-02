import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format/price.dart';
import '../../core/links/external_links.dart';
import '../cart/cart_models.dart';
import '../cart/cart_store.dart';
import 'orders_repository.dart';

/// Confirma el pedido a un vendedor: lo registra, lo quita del carrito y abre
/// WhatsApp con el detalle ya escrito.
Future<void> showPlaceOrderSheet(BuildContext context, CartGroup group) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlaceOrderSheet(group: group),
  );
}

class _PlaceOrderSheet extends StatefulWidget {
  final CartGroup group;

  const _PlaceOrderSheet({required this.group});

  @override
  State<_PlaceOrderSheet> createState() => _PlaceOrderSheetState();
}

class _PlaceOrderSheetState extends State<_PlaceOrderSheet> {
  static const _maxNoteLength = 300;

  final _noteController = TextEditingController();
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final links = context.read<ExternalLinks>();
    final cart = context.read<CartStore>();

    try {
      final note = _noteController.text.trim();
      final placed = await context.read<OrdersRepository>().place(
        groupKey: widget.group.key,
        note: note.isEmpty ? null : note,
      );
      // El pedido ya quitó esos productos del carrito en el servidor.
      cart.load();
      navigator.pop();

      final opened = await links.open(placed.whatsappUrl);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Pedido #${placed.order.id} creado. Síguelo en Perfil › Mis compras.'
                : 'Pedido #${placed.order.id} creado, pero no se pudo abrir '
                      'WhatsApp. Escríbele desde Perfil › Mis compras.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final textTheme = Theme.of(context).textTheme;
    final errorMessage = _errorMessage;
    final itemCount = group.items.fold(0, (sum, item) => sum + item.qty);

    return Padding(
      // Sube con el teclado al escribir la nota.
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pedido a ${group.seller.name}', style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '$itemCount producto(s) · ${formatBob(group.subtotalBob)}',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLength: _maxNoteLength,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nota para el vendedor (opcional)',
              hintText: 'Ej.: retiro el sábado, envío a Sopocachi...',
            ),
          ),
          Text(
            'Se abrirá WhatsApp con el detalle del pedido. El pago y la '
            'entrega se acuerdan directamente con el vendedor.',
            style: textTheme.bodySmall,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_outlined),
            label: const Text('Enviar por WhatsApp'),
          ),
        ],
      ),
    );
  }
}
