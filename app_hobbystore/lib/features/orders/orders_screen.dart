import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/format/price.dart';
import '../../core/links/external_links.dart';
import '../../core/widgets/coming_soon.dart';
import '../../core/widgets/error_retry.dart';
import 'order_models.dart';
import 'orders_repository.dart';

/// "Mis compras" (comprador) o "Pedidos recibidos" (vendedor).
class OrdersScreen extends StatefulWidget {
  final OrderRole role;

  const OrdersScreen({super.key, required this.role});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _orders;

  // En initState y no en el inicializador: provider prohíbe context.read en build.
  @override
  void initState() {
    super.initState();
    _orders = _load();
  }

  Future<List<Order>> _load() =>
      context.read<OrdersRepository>().list(widget.role);

  Future<void> _refresh() async {
    final reload = _load();
    setState(() {
      _orders = reload;
    });
    await reload;
  }

  @override
  Widget build(BuildContext context) {
    final isBuyer = widget.role == OrderRole.buyer;

    return Scaffold(
      appBar: AppBar(
        title: Text(isBuyer ? 'Mis compras' : 'Pedidos recibidos'),
      ),
      body: FutureBuilder(
        future: _orders,
        builder: (context, snapshot) {
          final orders = snapshot.data;
          if (orders != null && orders.isEmpty) {
            return ComingSoon(
              icon: Icons.receipt_long_outlined,
              message: isBuyer
                  ? 'Aún no hiciste pedidos. Arma tu carrito y pide por WhatsApp.'
                  : 'Aún no recibiste pedidos.',
            );
          }
          if (orders != null) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) =>
                    _OrderCard(order: orders[index], onChanged: _refresh),
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorRetry(
              message: errorMessageOf(snapshot.error),
              onRetry: _refresh,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;
  final Future<void> Function() onChanged;

  const _OrderCard({required this.order, required this.onChanged});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isUpdating = false;

  Future<void> _openWhatsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await context.read<ExternalLinks>().open(
      widget.order.whatsappUrl,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  Future<void> _changeStatus(String status) async {
    if (status == 'cancelled' && !await _confirmCancel()) return;
    if (!mounted) return;

    setState(() => _isUpdating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<OrdersRepository>().updateStatus(
        widget.order.id,
        status,
      );
      await widget.onChanged();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<bool> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Cancelar el pedido #${widget.order.id}?'),
        content: const Text(
          'Avisa también por WhatsApp para que la otra persona lo sepa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final textTheme = Theme.of(context).textTheme;
    final isBuyer = order.role == OrderRole.buyer;
    final note = order.note;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${order.id}',
                    style: textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: order.status),
              ],
            ),
            Text(
              '${_formatDate(order.createdAt)} · '
              '${isBuyer ? 'Vendedor' : 'Comprador'}: ${order.counterpartName}'
              '${order.counterpartCity == null ? '' : ' (${order.counterpartCity})'}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text('${item.qty} × ${item.title}')),
                    const SizedBox(width: 8),
                    Text(formatBob(item.priceBob * item.qty)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(child: Text('Total', style: textTheme.titleMedium)),
                Text(
                  formatBob(order.totalBob),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text('Nota: $note', style: textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(
                    isBuyer ? 'Escribir al vendedor' : 'Escribir al comprador',
                  ),
                ),
                for (final status in order.allowedStatuses)
                  status == 'cancelled'
                      ? TextButton(
                          onPressed: _isUpdating
                              ? null
                              : () => _changeStatus(status),
                          child: Text(orderStatusActions[status]!),
                        )
                      : FilledButton.tonal(
                          onPressed: _isUpdating
                              ? null
                              : () => _changeStatus(status),
                          child: Text(orderStatusActions[status] ?? status),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      'completed' => (colors.primaryContainer, colors.onPrimaryContainer),
      'cancelled' => (colors.surfaceContainerHighest, colors.outline),
      _ => (colors.tertiaryContainer, colors.onTertiaryContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          orderStatusLabels[status] ?? status,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
