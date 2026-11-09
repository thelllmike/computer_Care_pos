// Plain Dart models for Online Delivery feature.
// Uses direct Supabase queries — no Drift tables needed.

class OnlineOrderModel {
  final String id;
  final String orderNumber;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String customerAddress;
  final DateTime orderDate;
  final String deliveryStatus;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double totalCost;
  final double grossProfit;
  final double deliveryFee;
  final bool isPrepaid;
  final double paidAmount;
  final String paymentMethod;
  final String? trackingNumber;
  final String? notes;
  final String? deliveryNotes;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final bool stockDeducted;
  final bool salesCreated;
  final String? linkedSaleId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Nested items (populated on detail fetch)
  final List<OnlineOrderItemModel> items;

  const OnlineOrderModel({
    required this.id,
    required this.orderNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.customerAddress,
    required this.orderDate,
    required this.deliveryStatus,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.totalCost,
    required this.grossProfit,
    required this.deliveryFee,
    required this.isPrepaid,
    required this.paidAmount,
    required this.paymentMethod,
    this.trackingNumber,
    this.notes,
    this.deliveryNotes,
    this.shippedAt,
    this.deliveredAt,
    required this.stockDeducted,
    required this.salesCreated,
    this.linkedSaleId,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory OnlineOrderModel.fromMap(Map<String, dynamic> map) {
    return OnlineOrderModel(
      id: map['id'] as String,
      orderNumber: map['order_number'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      customerAddress: map['customer_address'] as String,
      orderDate: DateTime.parse(map['order_date'] as String),
      deliveryStatus: map['delivery_status'] as String,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (map['gross_profit'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      isPrepaid: (map['is_prepaid'] as bool?) ?? false,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (map['payment_method'] as String?) ?? 'CASH',
      trackingNumber: map['tracking_number'] as String?,
      notes: map['notes'] as String?,
      deliveryNotes: map['delivery_notes'] as String?,
      shippedAt: map['shipped_at'] != null
          ? DateTime.parse(map['shipped_at'] as String)
          : null,
      deliveredAt: map['delivered_at'] != null
          ? DateTime.parse(map['delivered_at'] as String)
          : null,
      stockDeducted: (map['stock_deducted'] as bool?) ?? false,
      salesCreated: (map['sales_created'] as bool?) ?? false,
      linkedSaleId: map['linked_sale_id'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      items: (map['online_order_items'] as List<dynamic>?)
              ?.map((e) => OnlineOrderItemModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'order_date': orderDate.toIso8601String(),
      'delivery_status': deliveryStatus,
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
      'tracking_number': trackingNumber,
      'notes': notes,
      'delivery_notes': deliveryNotes,
      'shipped_at': shippedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'stock_deducted': stockDeducted,
      'sales_created': salesCreated,
      'linked_sale_id': linkedSaleId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  OnlineOrderModel copyWith({List<OnlineOrderItemModel>? items}) {
    return OnlineOrderModel(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      orderDate: orderDate,
      deliveryStatus: deliveryStatus,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      totalCost: totalCost,
      grossProfit: grossProfit,
      deliveryFee: deliveryFee,
      isPrepaid: isPrepaid,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      trackingNumber: trackingNumber,
      notes: notes,
      deliveryNotes: deliveryNotes,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
      stockDeducted: stockDeducted,
      salesCreated: salesCreated,
      linkedSaleId: linkedSaleId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items ?? this.items,
    );
  }

  String get displayCustomerName =>
      customerName?.isNotEmpty == true ? customerName! : 'Guest Customer';
}

// ──────────────────────────────────────────────────────────────

class OnlineOrderItemModel {
  final String id;
  final String onlineOrderId;
  final String productId;
  final String? productName; // denormalized join
  final bool requiresSerial; // from products.requires_serial
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double discountAmount;
  final double totalPrice;
  final double totalCost;
  final double profit;
  final DateTime createdAt;

  // Serial numbers assigned to this item
  final List<OnlineOrderSerialModel> serials;

  const OnlineOrderItemModel({
    required this.id,
    required this.onlineOrderId,
    required this.productId,
    this.productName,
    this.requiresSerial = false,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.discountAmount,
    required this.totalPrice,
    required this.totalCost,
    required this.profit,
    required this.createdAt,
    this.serials = const [],
  });

  factory OnlineOrderItemModel.fromMap(Map<String, dynamic> map) {
    final productMap = map['products'] as Map<String, dynamic>?;
    return OnlineOrderItemModel(
      id: map['id'] as String,
      onlineOrderId: map['online_order_id'] as String,
      productId: map['product_id'] as String,
      productName: productMap?['name'] as String?,
      requiresSerial: (productMap?['requires_serial'] as bool?) ?? false,
      quantity: (map['quantity'] as num).toInt(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num).toDouble(),
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      profit: (map['profit'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      serials: (map['online_order_serials'] as List<dynamic>?)
              ?.map((e) =>
                  OnlineOrderSerialModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'online_order_id': onlineOrderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'discount_amount': discountAmount,
      'total_price': totalPrice,
      'total_cost': totalCost,
      'profit': profit,
    };
  }
}

// ──────────────────────────────────────────────────────────────

class OnlineOrderSerialModel {
  final String id;
  final String onlineOrderItemId;
  final String serialNumberId;
  final String serialNumber;
  final double unitCost;
  final DateTime createdAt;

  const OnlineOrderSerialModel({
    required this.id,
    required this.onlineOrderItemId,
    required this.serialNumberId,
    required this.serialNumber,
    required this.unitCost,
    required this.createdAt,
  });

  factory OnlineOrderSerialModel.fromMap(Map<String, dynamic> map) {
    return OnlineOrderSerialModel(
      id: map['id'] as String,
      onlineOrderItemId: map['online_order_item_id'] as String,
      serialNumberId: map['serial_number_id'] as String,
      serialNumber: map['serial_number'] as String,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'online_order_item_id': onlineOrderItemId,
      'serial_number_id': serialNumberId,
      'serial_number': serialNumber,
      'unit_cost': unitCost,
    };
  }
}
