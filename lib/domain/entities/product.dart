import '../../core/enums/product_type.dart';

class Product {
  final String id;
  final String code;
  final String? barcode;
  final String name;
  final String? description;
  final String? categoryId;
  final ProductType productType;
  final bool requiresSerial;
  final double sellingPrice;
  final double weightedAvgCost;
  final int warrantyMonths;
  final int reorderLevel;
  final String? brand;
  final String? model;
  final Map<String, dynamic>? specifications;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.code,
    this.barcode,
    required this.name,
    this.description,
    this.categoryId,
    required this.productType,
    required this.requiresSerial,
    required this.sellingPrice,
    required this.weightedAvgCost,
    required this.warrantyMonths,
    required this.reorderLevel,
    this.brand,
    this.model,
    this.specifications,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  double get profit => sellingPrice - weightedAvgCost;
  double get profitMargin => weightedAvgCost > 0 ? (profit / sellingPrice) * 100 : 0;

  Product copyWith({
    String? id,
    String? code,
    String? barcode,
    String? name,
    String? description,
    String? categoryId,
    ProductType? productType,
    bool? requiresSerial,
    double? sellingPrice,
    double? weightedAvgCost,
    int? warrantyMonths,
    int? reorderLevel,
    String? brand,
    String? model,
    Map<String, dynamic>? specifications,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      productType: productType ?? this.productType,
      requiresSerial: requiresSerial ?? this.requiresSerial,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      weightedAvgCost: weightedAvgCost ?? this.weightedAvgCost,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      specifications: specifications ?? this.specifications,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
