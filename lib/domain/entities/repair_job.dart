import '../../core/enums/repair_status.dart';

class RepairJob {
  final String id;
  final String jobNumber;
  final String customerId;
  final String? serialNumberId;
  final String deviceType;
  final String? deviceBrand;
  final String? deviceModel;
  final String? deviceSerial;
  final String problemDescription;
  final String? diagnosis;
  final double estimatedCost;
  final double actualCost;
  final double laborCost;
  final double partsCost;
  final double totalCost;
  final RepairStatus status;
  final bool isUnderWarranty;
  final String? warrantyNotes;
  final DateTime receivedDate;
  final DateTime? promisedDate;
  final DateTime? completedDate;
  final DateTime? deliveredDate;
  final String? receivedBy;
  final String? assignedTo;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<RepairPart> parts;

  const RepairJob({
    required this.id,
    required this.jobNumber,
    required this.customerId,
    this.serialNumberId,
    required this.deviceType,
    this.deviceBrand,
    this.deviceModel,
    this.deviceSerial,
    required this.problemDescription,
    this.diagnosis,
    required this.estimatedCost,
    required this.actualCost,
    required this.laborCost,
    required this.partsCost,
    required this.totalCost,
    required this.status,
    required this.isUnderWarranty,
    this.warrantyNotes,
    required this.receivedDate,
    this.promisedDate,
    this.completedDate,
    this.deliveredDate,
    this.receivedBy,
    this.assignedTo,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.parts = const [],
  });

  bool get isActive => status.isActive;
  bool get isCompleted => status == RepairStatus.completed || status == RepairStatus.readyForPickup || status == RepairStatus.delivered;
  bool get isOverdue => promisedDate != null && DateTime.now().isAfter(promisedDate!) && !isCompleted;
}

class RepairPart {
  final String id;
  final String repairJobId;
  final String productId;
  final String? serialNumberId;
  final int quantity;
  final double unitCost;
  final double unitPrice;
  final double totalCost;
  final double totalPrice;

  const RepairPart({
    required this.id,
    required this.repairJobId,
    required this.productId,
    this.serialNumberId,
    required this.quantity,
    required this.unitCost,
    required this.unitPrice,
    required this.totalCost,
    required this.totalPrice,
  });

  double get profit => totalPrice - totalCost;
}
