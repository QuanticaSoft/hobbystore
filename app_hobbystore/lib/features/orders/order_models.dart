enum OrderRole { buyer, seller }

const orderStatusLabels = {
  'pending': 'Pendiente',
  'contacted': 'Contactado',
  'confirmed': 'Confirmado',
  'completed': 'Entregado',
  'cancelled': 'Cancelado',
};

/// Texto del botón que lleva un pedido a cada estado.
const orderStatusActions = {
  'contacted': 'Marcar contactado',
  'confirmed': 'Confirmar',
  'completed': 'Marcar entregado',
  'cancelled': 'Cancelar pedido',
};

class OrderItem {
  final int? productId;
  final String title;
  final double priceBob;
  final int qty;

  const OrderItem({
    required this.productId,
    required this.title,
    required this.priceBob,
    required this.qty,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: json['product_id'] as int?,
    title: json['title'] as String,
    priceBob: (json['price_bob'] as num).toDouble(),
    qty: json['qty'] as int,
  );
}

class Order {
  final int id;
  final String status;
  final OrderRole role;
  final double totalBob;
  final String? note;
  final DateTime createdAt;
  final String counterpartName;
  final String? counterpartCity;
  final bool isStore;
  final List<OrderItem> items;

  /// Estados a los que este usuario puede llevar el pedido (lo decide la API).
  final List<String> allowedStatuses;
  final Uri whatsappUrl;

  const Order({
    required this.id,
    required this.status,
    required this.role,
    required this.totalBob,
    required this.createdAt,
    required this.counterpartName,
    required this.isStore,
    required this.items,
    required this.allowedStatuses,
    required this.whatsappUrl,
    this.note,
    this.counterpartCity,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final counterpart = json['counterpart'] as Map<String, dynamic>;
    return Order(
      id: json['id'] as int,
      status: json['status'] as String,
      role: OrderRole.values.byName(json['role'] as String),
      totalBob: (json['total_bob'] as num).toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      counterpartName: counterpart['name'] as String,
      counterpartCity: counterpart['city'] as String?,
      isStore: json['is_store'] as bool,
      items: (json['items'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      allowedStatuses: List<String>.from(json['allowed_statuses'] as List),
      whatsappUrl: Uri.parse(json['whatsapp_url'] as String),
    );
  }

  bool get isClosed => status == 'completed' || status == 'cancelled';
}

/// Resultado de crear un pedido: el registro y el chat con el mensaje listo.
class PlacedOrder {
  final Order order;
  final Uri whatsappUrl;

  const PlacedOrder({required this.order, required this.whatsappUrl});

  factory PlacedOrder.fromJson(Map<String, dynamic> json) => PlacedOrder(
    order: Order.fromJson(json['order'] as Map<String, dynamic>),
    whatsappUrl: Uri.parse(json['whatsapp_url'] as String),
  );
}
