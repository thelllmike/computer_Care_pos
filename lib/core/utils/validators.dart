class Validators {
  Validators._();

  /// Validates an email address
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validates that a field is not empty
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates a phone number
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null; // Optional
    final phoneRegex = RegExp(r'^[0-9+\-\s()]{7,20}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Validates a positive number
  static String? positiveNumber(String? value, [String fieldName = 'Value']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }
    if (number < 0) {
      return '$fieldName must be positive';
    }
    return null;
  }

  /// Validates a positive integer
  static String? positiveInteger(String? value, [String fieldName = 'Value']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final number = int.tryParse(value);
    if (number == null) {
      return 'Please enter a valid whole number';
    }
    if (number < 0) {
      return '$fieldName must be positive';
    }
    return null;
  }

  /// Validates minimum length
  static String? minLength(String? value, int minLength,
      [String fieldName = 'This field']) {
    if (value == null || value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  /// Validates maximum length
  static String? maxLength(String? value, int maxLength,
      [String fieldName = 'This field']) {
    if (value != null && value.length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }
    return null;
  }

  /// Validates a barcode format
  static String? barcode(String? value) {
    if (value == null || value.isEmpty) return null; // Optional
    // Allow alphanumeric barcodes
    final barcodeRegex = RegExp(r'^[A-Za-z0-9\-]+$');
    if (!barcodeRegex.hasMatch(value)) {
      return 'Please enter a valid barcode';
    }
    return null;
  }

  /// Validates a serial number format
  static String? serialNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Serial number is required';
    }
    // Allow alphanumeric serial numbers with dashes
    final serialRegex = RegExp(r'^[A-Za-z0-9\-_]+$');
    if (!serialRegex.hasMatch(value)) {
      return 'Please enter a valid serial number';
    }
    return null;
  }

  /// Validates price (must be >= 0)
  static String? price(String? value, [String fieldName = 'Price']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid price';
    }
    if (price < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  /// Validates quantity (must be > 0)
  static String? quantity(String? value, [String fieldName = 'Quantity']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final qty = int.tryParse(value);
    if (qty == null) {
      return 'Please enter a valid quantity';
    }
    if (qty <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }

  /// Combines multiple validators
  static String? compose(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) return result;
    }
    return null;
  }
}
