enum SerialStatus {
  inStock,
  sold,
  returned,
  inRepair,
  defective,
  disposed,
}

extension SerialStatusExtension on SerialStatus {
  String get displayName {
    switch (this) {
      case SerialStatus.inStock:
        return 'In Stock';
      case SerialStatus.sold:
        return 'Sold';
      case SerialStatus.returned:
        return 'Returned';
      case SerialStatus.inRepair:
        return 'In Repair';
      case SerialStatus.defective:
        return 'Defective';
      case SerialStatus.disposed:
        return 'Disposed';
    }
  }

  String get code {
    switch (this) {
      case SerialStatus.inStock:
        return 'IN_STOCK';
      case SerialStatus.sold:
        return 'SOLD';
      case SerialStatus.returned:
        return 'RETURNED';
      case SerialStatus.inRepair:
        return 'IN_REPAIR';
      case SerialStatus.defective:
        return 'DEFECTIVE';
      case SerialStatus.disposed:
        return 'DISPOSED';
    }
  }

  static SerialStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IN_STOCK':
        return SerialStatus.inStock;
      case 'SOLD':
        return SerialStatus.sold;
      case 'RETURNED':
        return SerialStatus.returned;
      case 'IN_REPAIR':
        return SerialStatus.inRepair;
      case 'DEFECTIVE':
        return SerialStatus.defective;
      case 'DISPOSED':
        return SerialStatus.disposed;
      default:
        return SerialStatus.inStock;
    }
  }
}
