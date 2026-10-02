import '../../core/api/api_client.dart';
import 'order_models.dart';

class OrdersRepository {
  final ApiClient api;

  const OrdersRepository(this.api);

  Future<PlacedOrder> place({required String groupKey, String? note}) async =>
      PlacedOrder.fromJson(
        await api.post('/orders', {'group_key': groupKey, 'note': ?note}),
      );

  Future<List<Order>> list(OrderRole role) async {
    final data = await api.get('/orders', query: {'role': role.name});
    return (data['orders'] as List)
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Order> updateStatus(int orderId, String status) async {
    final data = await api.patch('/orders/$orderId', {'status': status});
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }
}
