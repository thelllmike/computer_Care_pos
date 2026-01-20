import '../../core/enums/serial_status.dart';

class SerialNumber {
  final String id;
  final String serialNumber;
  final String productId;
  final SerialStatus status;
  final double unitCost;
  final String? grnId;
  final String? grnItemId;
  final String? saleId;
  final String? customerId;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SerialNumber({
    required this.id,
    required this.serialNumber,
    required this.productId,
    required this.status,
    required this.unitCost,
    this.grnId,
    this.grnItemId,
    this.saleId,
    this.customerId,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isInStock => status == SerialStatus.inStock;
  bool get isSold => status == SerialStatus.sold;
  bool get isInRepair => status == SerialStatus.inRepair;

  bool get isUnderWarranty {
    if (warrantyEndDate == null) return false;
    return DateTime.now().isBefore(warrantyEndDate!);
  }

  int? get warrantyDaysRemaining {
    if (warrantyEndDate == null) return null;
    final now = DateTime.now();
    if (now.isAfter(warrantyEndDate!)) return 0;
    return warrantyEndDate!.difference(now).inDays;
  }

  SerialNumber copyWith({
    String? id,
    String? serialNumber,
    String? productId,
    SerialStatus? status,
    double? unitCost,
    String? grnId,
    String? grnItemId,
    String? saleId,
    String? customerId,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SerialNumber(
      id: id ?? this.id,
      serialNumber: serialNumber ?? this.serialNumber,
      productId: productId ?? this.productId,
      status: status ?? this.status,
      unitCost: unitCost ?? this.unitCost,
      grnId: grnId ?? this.grnId,
      grnItemId: grnItemId ?? this.grnItemId,
      saleId: saleId ?? this.saleId,
      customerId: customerId ?? this.customerId,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
