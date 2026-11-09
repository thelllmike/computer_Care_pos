import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/online_order_model.dart';

class OnlineDeliveryService {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  OnlineDeliveryService(this._client);

  // ──────────────────────────────────────────────────────────
  // Fetch orders list
  // ──────────────────────────────────────────────────────────
  Future<List<OnlineOrderModel>> fetchOrders({
    String? status,
    String? search,
  }) async {
    final List<dynamic> data;

    if (status != null && status.isNotEmpty) {
      data = await _client
          .from('online_orders')
          .select('*')
          .eq('delivery_status', status)
          .order('created_at', ascending: false);
    } else {
      data = await _client
          .from('online_orders')
          .select('*')
          .order('created_at', ascending: false);
    }

    var orders = data
        .map((e) => OnlineOrderModel.fromMap(e as Map<String, dynamic>))
        .toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      orders = orders.where((o) {
        return o.orderNumber.toLowerCase().contains(q) ||
            (o.customerName?.toLowerCase().contains(q) ?? false) ||
            (o.customerPhone?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return orders;
  }

  // ──────────────────────────────────────────────────────────
  // Fetch single order by id (with items + serials)
  // ──────────────────────────────────────────────────────────
  Future<OnlineOrderModel?> fetchOrderById(String id) async {
    final data = await _client
        .from('online_orders')
        .select('*')
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;

    final order = OnlineOrderModel.fromMap(data);
    final items = await fetchOrderItems(id);
    return order.copyWith(items: items);
  }

  // ──────────────────────────────────────────────────────────
  // Get next order number via RPC
  // ──────────────────────────────────────────────────────────
  Future<String> getNextOrderNumber() async {
    final result = await _client.rpc(
      'get_next_sequence',
      params: {'p_sequence_type': 'ONLINE_ORDER'},
    );
    return result as String;
  }

  // ──────────────────────────────────────────────────────────
  // Create order (insert header + items)
  // ──────────────────────────────────────────────────────────
  Future<OnlineOrderModel> createOrder({
    required String? customerId,
    required String? customerName,
    required String? customerPhone,
    required String customerAddress,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double totalAmount,
    required double totalCost,
    required double grossProfit,
    required double deliveryFee,
    required bool isPrepaid,
    required double paidAmount,
    required String paymentMethod,
    String? notes,
    required String createdBy,
    required List<Map<String, dynamic>> itemsData,
  }) async {
    final orderId = _uuid.v4();
    final orderNumber = await getNextOrderNumber();
    final now = DateTime.now().toUtc().toIso8601String();

    // Insert order header
    await _client.from('online_orders').insert({
      'id': orderId,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'order_date': now,
      'delivery_status': 'PENDING',
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'total_cost': totalCost,
      'gross_profit': grossProfit,
      'delivery_fee': deliveryFee,
      'is_prepaid': isPrepaid,
      'paid_amount': paidAmount,
      'payment_method': paymentMethod,
      'notes': notes,
      'stock_deducted': false,
      'sales_created': false,
      'created_by': createdBy,
      'sync_status': 'SYNCED',
    });

    // Insert items
    for (final item in itemsData) {
      final itemId = _uuid.v4();
      await _client.from('online_order_items').insert({
        'id': itemId,
        'online_order_id': orderId,
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'unit_cost': item['unit_cost'] ?? 0.0,
        'discount_amount': item['discount_amount'] ?? 0.0,
        'total_price': item['total_price'],
        'total_cost': item['total_cost'] ?? 0.0,
        'profit': item['profit'] ?? 0.0,
        'sync_status': 'SYNCED',
      });
    }

    final created = await fetchOrderById(orderId);
    return created!;
  }

  // ──────────────────────────────────────────────────────────
  // Update order status (simple transitions)
  // ──────────────────────────────────────────────────────────
  Future<void> updateOrderStatus(String id, String status) async {
    await _client
        .from('online_orders')
        .update({'delivery_status': status})
        .eq('id', id);
  }

  // ──────────────────────────────────────────────────────────
  // Assign serials to an order item
  // ──────────────────────────────────────────────────────────
  Future<void> assignSerials(
    String orderId,
    String itemId,
    List<Map<String, String>> serials,
  ) async {
    // Delete existing serials for this item first
    await _client
        .from('online_order_serials')
        .delete()
        .eq('online_order_item_id', itemId);

    // Insert new serials
    for (final s in serials) {
      await _client.from('online_order_serials').insert({
        'id': _uuid.v4(),
        'online_order_item_id': itemId,
        'serial_number_id': s['serial_number_id'],
        'serial_number': s['serial_number'],
        'unit_cost': double.tryParse(s['unit_cost'] ?? '0') ?? 0.0,
        'sync_status': 'SYNCED',
      });
    }
  }

  // ──────────────────────────────────────────────────────────
  // Mark as Shipped — calls process_online_order_delivery RPC
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> markShipped(
      String orderId, String userId) async {
    final result = await _client.rpc(
      'process_online_order_delivery',
      params: {
        'p_online_order_id': orderId,
        'p_user_id': userId,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  // ──────────────────────────────────────────────────────────
  // Mark as Delivered — calls mark_online_order_delivered RPC
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> markDelivered(
      String orderId, String userId) async {
    final result = await _client.rpc(
      'mark_online_order_delivered',
      params: {
        'p_online_order_id': orderId,
        'p_user_id': userId,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  // ──────────────────────────────────────────────────────────
  // Search customers for autocomplete
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    if (query.isEmpty) return [];
    final data = await _client
        .from('customers')
        .select('id, name, phone')
        .or('name.ilike.%$query%,phone.ilike.%$query%')
        .limit(10);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ──────────────────────────────────────────────────────────
  // Search products for order line items
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.isEmpty) return [];
    final data = await _client
        .from('products')
        .select('id, code, name, selling_price, weighted_avg_cost, '
            'requires_serial, brand, model')
        .or('name.ilike.%$query%,'
            'code.ilike.%$query%,'
            'barcode.ilike.%$query%,'
            'brand.ilike.%$query%,'
            'model.ilike.%$query%')
        .eq('is_active', true)
        .order('name')
        .limit(15);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ──────────────────────────────────────────────────────────
  // Fetch available (IN_STOCK) serials for a product
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAvailableSerials(
      String productId) async {
    final data = await _client
        .from('serial_numbers')
        .select('id, serial_number, cost_price')
        .eq('product_id', productId)
        .eq('status', 'IN_STOCK')
        .order('serial_number');
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ──────────────────────────────────────────────────────────
  // Fetch order items (two-step: items+serials, then products)
  // Avoids relying on PostgREST FK relationship resolution so
  // the query works even when the schema cache is stale.
  // ──────────────────────────────────────────────────────────
  Future<List<OnlineOrderItemModel>> fetchOrderItems(String orderId) async {
    // Step 1: fetch items and their assigned serials.
    // online_order_serials FK to online_order_items IS declared,
    // so this nested select is safe.
    final rawItems = await _client
        .from('online_order_items')
        .select('*, online_order_serials(*)')
        .eq('online_order_id', orderId)
        .order('created_at');

    final items = rawItems as List;
    if (items.isEmpty) return [];

    // Step 2: collect the distinct product IDs referenced by these items.
    final productIds = items
        .map((e) => (e as Map<String, dynamic>)['product_id'] as String)
        .toSet()
        .toList();

    // Step 3: fetch those products directly — no relationship join needed.
    final rawProducts = await _client
        .from('products')
        .select('id, name, requires_serial')
        .inFilter('id', productIds);

    // Step 4: build an id→product lookup map.
    final productById = <String, Map<String, dynamic>>{
      for (final p in rawProducts as List)
        (p as Map<String, dynamic>)['id'] as String: p,
    };

    // Step 5: merge product data into each item map and parse.
    return items.map((e) {
      final item = Map<String, dynamic>.from(e as Map<String, dynamic>);
      // Inject as 'products' key so OnlineOrderItemModel.fromMap
      // continues to work without any model changes.
      item['products'] = productById[item['product_id'] as String];
      return OnlineOrderItemModel.fromMap(item);
    }).toList();
  }

  // ──────────────────────────────────────────────────────────
  // Fetch serials for an order (flat list)
  // ──────────────────────────────────────────────────────────
  Future<List<OnlineOrderSerialModel>> fetchOrderSerials(
      String orderId) async {
    final data = await _client
        .from('online_order_serials')
        .select('*, online_order_items!inner(online_order_id)')
        .eq('online_order_items.online_order_id', orderId);
    return (data as List)
        .map((e) =>
            OnlineOrderSerialModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
