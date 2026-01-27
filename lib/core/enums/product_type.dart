enum ProductType {
  laptop,
  desktop,
  mobile,
  printer,
  cctv,
  accessory,
  sparePart,
}

extension ProductTypeExtension on ProductType {
  String get displayName {
    switch (this) {
      case ProductType.laptop:
        return 'Laptop';
      case ProductType.desktop:
        return 'Desktop';
      case ProductType.mobile:
        return 'Mobile';
      case ProductType.printer:
        return 'Printer';
      case ProductType.cctv:
        return 'CCTV';
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
      case ProductType.desktop:
        return 'DESKTOP';
      case ProductType.mobile:
        return 'MOBILE';
      case ProductType.printer:
        return 'PRINTER';
      case ProductType.cctv:
        return 'CCTV';
      case ProductType.accessory:
        return 'ACCESSORY';
      case ProductType.sparePart:
        return 'SPARE_PART';
    }
  }

  bool get requiresSerial {
    switch (this) {
      case ProductType.laptop:
      case ProductType.desktop:
      case ProductType.mobile:
      case ProductType.printer:
      case ProductType.cctv:
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
      case 'DESKTOP':
        return ProductType.desktop;
      case 'MOBILE':
        return ProductType.mobile;
      case 'PRINTER':
        return ProductType.printer;
      case 'CCTV':
        return ProductType.cctv;
      case 'ACCESSORY':
        return ProductType.accessory;
      case 'SPARE_PART':
        return ProductType.sparePart;
      default:
        return ProductType.accessory;
    }
  }
}
