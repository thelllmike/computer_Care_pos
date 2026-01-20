enum ProductType {
  laptop,
  accessory,
  sparePart,
}

extension ProductTypeExtension on ProductType {
  String get displayName {
    switch (this) {
      case ProductType.laptop:
        return 'Laptop';
      case ProductType.accessory:
        return 'Accessory';
      case ProductType.sparePart:
        return 'Spare Part';
    }
  }

  String get code {
    switch (this) {
      case ProductType.laptop:
        return 'LAPTOP';
      case ProductType.accessory:
        return 'ACCESSORY';
      case ProductType.sparePart:
        return 'SPARE_PART';
    }
  }

  bool get requiresSerial {
    switch (this) {
      case ProductType.laptop:
        return true;
      case ProductType.accessory:
      case ProductType.sparePart:
        return false;
    }
  }

  static ProductType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'LAPTOP':
        return ProductType.laptop;
      case 'ACCESSORY':
        return ProductType.accessory;
      case 'SPARE_PART':
        return ProductType.sparePart;
      default:
        return ProductType.accessory;
    }
  }
}
