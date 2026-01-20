class Customer {
  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? nic;
  final bool creditEnabled;
  final double creditLimit;
  final double creditBalance;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Customer({
    required this.id,
    required this.code,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.nic,
    required this.creditEnabled,
    required this.creditLimit,
    required this.creditBalance,
    this.notes,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  double get availableCredit => creditLimit - creditBalance;
  bool get hasOutstanding => creditBalance > 0;

  Customer copyWith({
    String? id,
    String? code,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? nic,
    bool? creditEnabled,
    double? creditLimit,
    double? creditBalance,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      nic: nic ?? this.nic,
      creditEnabled: creditEnabled ?? this.creditEnabled,
      creditLimit: creditLimit ?? this.creditLimit,
      creditBalance: creditBalance ?? this.creditBalance,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
