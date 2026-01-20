enum RepairStatus {
  received,
  diagnosing,
  waitingForParts,
  inProgress,
  completed,
  readyForPickup,
  delivered,
  cancelled,
}

extension RepairStatusExtension on RepairStatus {
  String get displayName {
    switch (this) {
      case RepairStatus.received:
        return 'Received';
      case RepairStatus.diagnosing:
        return 'Diagnosing';
      case RepairStatus.waitingForParts:
        return 'Waiting for Parts';
      case RepairStatus.inProgress:
        return 'In Progress';
      case RepairStatus.completed:
        return 'Completed';
      case RepairStatus.readyForPickup:
        return 'Ready for Pickup';
      case RepairStatus.delivered:
        return 'Delivered';
      case RepairStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get code {
    switch (this) {
      case RepairStatus.received:
        return 'RECEIVED';
      case RepairStatus.diagnosing:
        return 'DIAGNOSING';
      case RepairStatus.waitingForParts:
        return 'WAITING_FOR_PARTS';
      case RepairStatus.inProgress:
        return 'IN_PROGRESS';
      case RepairStatus.completed:
        return 'COMPLETED';
      case RepairStatus.readyForPickup:
        return 'READY_FOR_PICKUP';
      case RepairStatus.delivered:
        return 'DELIVERED';
      case RepairStatus.cancelled:
        return 'CANCELLED';
    }
  }

  bool get isActive {
    switch (this) {
      case RepairStatus.received:
      case RepairStatus.diagnosing:
      case RepairStatus.waitingForParts:
      case RepairStatus.inProgress:
      case RepairStatus.completed:
      case RepairStatus.readyForPickup:
        return true;
      case RepairStatus.delivered:
      case RepairStatus.cancelled:
        return false;
    }
  }

  static RepairStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'RECEIVED':
        return RepairStatus.received;
      case 'DIAGNOSING':
        return RepairStatus.diagnosing;
      case 'WAITING_FOR_PARTS':
        return RepairStatus.waitingForParts;
      case 'IN_PROGRESS':
        return RepairStatus.inProgress;
      case 'COMPLETED':
        return RepairStatus.completed;
      case 'READY_FOR_PICKUP':
        return RepairStatus.readyForPickup;
      case 'DELIVERED':
        return RepairStatus.delivered;
      case 'CANCELLED':
        return RepairStatus.cancelled;
      default:
        return RepairStatus.received;
    }
  }
}
