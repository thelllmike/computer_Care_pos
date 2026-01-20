enum UserRole {
  admin,
  cashier,
  technician,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.technician:
        return 'Technician';
    }
  }

  String get code {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.cashier:
        return 'CASHIER';
      case UserRole.technician:
        return 'TECHNICIAN';
    }
  }

  bool get canManageProducts {
    return this == UserRole.admin;
  }

  bool get canManageUsers {
    return this == UserRole.admin;
  }

  bool get canAdjustStock {
    return this == UserRole.admin;
  }

  bool get canViewReports {
    return this == UserRole.admin;
  }

  bool get canProcessSales {
    return this == UserRole.admin || this == UserRole.cashier;
  }

  bool get canManageRepairs {
    return this == UserRole.admin || this == UserRole.technician;
  }

  static UserRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'CASHIER':
        return UserRole.cashier;
      case 'TECHNICIAN':
        return UserRole.technician;
      default:
        return UserRole.cashier;
    }
  }
}
