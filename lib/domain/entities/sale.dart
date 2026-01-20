class Sale {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String? quotationId;
  final DateTime saleDate;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double totalCost;
  final double grossProfit;
  final bool isCredit;
  final String status;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    this.quotationId,
    required this.saleDate,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.totalCost,
    required this.grossProfit,
    required this.isCredit,
    required this.status,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  double get outstandingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => paidAmount >= totalAmount;
  double get profitMargin => totalAmount > 0 ? (grossProfit / totalAmount) * 100 : 0;
}

class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double discountAmount;
  final double totalPrice;
  final double totalCost;
  final double profit;
  final List<SaleSerial> serials;

  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.discountAmount,
    required this.totalPrice,
    required this.totalCost,
    required this.profit,
    this.serials = const [],
  });
}

class SaleSerial {
  final String id;
  final String saleItemId;
  final String serialNumberId;
  final String serialNumber;
  final double unitCost;

  const SaleSerial({
    required this.id,
    required this.saleItemId,
    required this.serialNumberId,
    required this.serialNumber,
    required this.unitCost,
  });
}
