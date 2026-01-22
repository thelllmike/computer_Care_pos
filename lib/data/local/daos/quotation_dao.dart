import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../tables/quotations_table.dart';
import '../tables/products_table.dart';
import '../tables/customers_table.dart';
import 'sales_dao.dart';

part 'quotation_dao.g.dart';

// Quotation status enum
enum QuotationStatus {
  draft('DRAFT'),
  sent('SENT'),
  accepted('ACCEPTED'),
  rejected('REJECTED'),
  expired('EXPIRED'),
  converted('CONVERTED');

  final String code;
  const QuotationStatus(this.code);

  static QuotationStatus fromCode(String code) {
    return QuotationStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => QuotationStatus.draft,
    );
  }
}

@DriftAccessor(tables: [Quotations, QuotationItems, Products, Customers])
class QuotationDao extends DatabaseAccessor<AppDatabase> with _$QuotationDaoMixin {
  QuotationDao(super.db);

  static const _uuid = Uuid();

  // ==================== Quotation Operations ====================

  // Get all quotations
  Future<List<QuotationWithCustomer>> getAllQuotations() async {
    final query = select(quotations).join([
      leftOuterJoin(customers, customers.id.equalsExp(quotations.customerId)),
    ])
      ..orderBy([OrderingTerm.desc(quotations.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return QuotationWithCustomer(
        quotation: row.readTable(quotations),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Get quotations by status
  Future<List<QuotationWithCustomer>> getQuotationsByStatus(QuotationStatus status) async {
    final query = select(quotations).join([
      leftOuterJoin(customers, customers.id.equalsExp(quotations.customerId)),
    ])
      ..where(quotations.status.equals(status.code))
      ..orderBy([OrderingTerm.desc(quotations.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return QuotationWithCustomer(
        quotation: row.readTable(quotations),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Get quotation by ID
  Future<Quotation?> getQuotationById(String id) {
    return (select(quotations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get quotation detail with items
  Future<QuotationDetail?> getQuotationDetail(String id) async {
    final quotation = await getQuotationById(id);
    if (quotation == null) return null;

    final customer = quotation.customerId != null
        ? await (select(customers)..where((t) => t.id.equals(quotation.customerId!))).getSingleOrNull()
        : null;

    final items = await getQuotationItems(id);

    return QuotationDetail(
      quotation: quotation,
      customer: customer,
      items: items,
    );
  }

  // Watch quotation by ID
  Stream<Quotation?> watchQuotationById(String id) {
    return (select(quotations)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  // Search quotations
  Future<List<QuotationWithCustomer>> searchQuotations(String query) async {
    final searchTerm = '%$query%';
    final queryBuilder = select(quotations).join([
      leftOuterJoin(customers, customers.id.equalsExp(quotations.customerId)),
    ])
      ..where(quotations.quotationNumber.like(searchTerm) |
              customers.name.like(searchTerm))
      ..orderBy([OrderingTerm.desc(quotations.createdAt)]);

    final results = await queryBuilder.get();
    return results.map((row) {
      return QuotationWithCustomer(
        quotation: row.readTable(quotations),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Create quotation
  Future<Quotation> createQuotation({
    String? customerId,
    DateTime? validUntil,
    String? notes,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final quotationNumber = await db.getNextSequenceNumber('QUOTATION');

    await into(quotations).insert(QuotationsCompanion.insert(
      id: id,
      quotationNumber: quotationNumber,
      quotationDate: now,
      customerId: Value(customerId),
      validUntil: Value(validUntil ?? now.add(const Duration(days: 30))),
      status: const Value('DRAFT'),
      notes: Value(notes),
      createdBy: Value(createdBy),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    return (await getQuotationById(id))!;
  }

  // Update quotation
  Future<bool> updateQuotation({
    required String id,
    String? customerId,
    DateTime? validUntil,
    String? notes,
    bool clearCustomer = false,
  }) async {
    final now = DateTime.now();

    return await (update(quotations)..where((t) => t.id.equals(id))).write(
      QuotationsCompanion(
        customerId: clearCustomer ? const Value(null) : (customerId != null ? Value(customerId) : const Value.absent()),
        validUntil: validUntil != null ? Value(validUntil) : const Value.absent(),
        notes: Value(notes),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    ) > 0;
  }

  // Update quotation status
  Future<bool> updateQuotationStatus(String id, QuotationStatus status) async {
    final now = DateTime.now();

    return await (update(quotations)..where((t) => t.id.equals(id))).write(
      QuotationsCompanion(
        status: Value(status.code),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    ) > 0;
  }

  // Delete quotation (only drafts)
  Future<bool> deleteQuotation(String id) async {
    final quotation = await getQuotationById(id);
    if (quotation == null || quotation.status != 'DRAFT') {
      return false;
    }

    // Delete items first
    await (delete(quotationItems)..where((t) => t.quotationId.equals(id))).go();

    // Delete quotation
    return await (delete(quotations)..where((t) => t.id.equals(id))).go() > 0;
  }

  // ==================== Quotation Items ====================

  // Get quotation items
  Future<List<QuotationItemWithProduct>> getQuotationItems(String quotationId) async {
    final query = select(quotationItems).join([
      innerJoin(products, products.id.equalsExp(quotationItems.productId)),
    ])
      ..where(quotationItems.quotationId.equals(quotationId))
      ..orderBy([OrderingTerm.asc(quotationItems.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return QuotationItemWithProduct(
        item: row.readTable(quotationItems),
        product: row.readTable(products),
      );
    }).toList();
  }

  // Add quotation item
  Future<QuotationItem> addQuotationItem({
    required String quotationId,
    required String productId,
    required int quantity,
    required double unitPrice,
    double discountAmount = 0,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final totalPrice = (unitPrice * quantity) - discountAmount;

    await into(quotationItems).insert(QuotationItemsCompanion.insert(
      id: id,
      quotationId: quotationId,
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      discountAmount: Value(discountAmount),
      notes: Value(notes),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Update quotation totals
    await _updateQuotationTotals(quotationId);

    return (await (select(quotationItems)..where((t) => t.id.equals(id))).getSingle());
  }

  // Update quotation item
  Future<bool> updateQuotationItem({
    required String itemId,
    int? quantity,
    double? unitPrice,
    double? discountAmount,
    String? notes,
  }) async {
    final item = await (select(quotationItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return false;

    final now = DateTime.now();
    final newQuantity = quantity ?? item.quantity;
    final newUnitPrice = unitPrice ?? item.unitPrice;
    final newDiscount = discountAmount ?? item.discountAmount;
    final totalPrice = (newUnitPrice * newQuantity) - newDiscount;

    final result = await (update(quotationItems)..where((t) => t.id.equals(itemId))).write(
      QuotationItemsCompanion(
        quantity: Value(newQuantity),
        unitPrice: Value(newUnitPrice),
        discountAmount: Value(newDiscount),
        totalPrice: Value(totalPrice),
        notes: Value(notes),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    ) > 0;

    if (result) {
      await _updateQuotationTotals(item.quotationId);
    }

    return result;
  }

  // Remove quotation item
  Future<bool> removeQuotationItem(String itemId) async {
    final item = await (select(quotationItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return false;

    final quotationId = item.quotationId;
    final result = await (delete(quotationItems)..where((t) => t.id.equals(itemId))).go() > 0;

    if (result) {
      await _updateQuotationTotals(quotationId);
    }

    return result;
  }

  // Update quotation totals
  Future<void> _updateQuotationTotals(String quotationId) async {
    final items = await (select(quotationItems)..where((t) => t.quotationId.equals(quotationId))).get();

    double subtotal = 0;
    double itemDiscounts = 0;

    for (final item in items) {
      subtotal += item.unitPrice * item.quantity;
      itemDiscounts += item.discountAmount;
    }

    final quotation = await getQuotationById(quotationId);
    final totalAmount = subtotal - itemDiscounts - (quotation?.discountAmount ?? 0) + (quotation?.taxAmount ?? 0);

    final now = DateTime.now();
    await (update(quotations)..where((t) => t.id.equals(quotationId))).write(
      QuotationsCompanion(
        subtotal: Value(subtotal),
        totalAmount: Value(totalAmount),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // Apply discount to quotation
  Future<void> applyQuotationDiscount(String quotationId, double discountAmount) async {
    final quotation = await getQuotationById(quotationId);
    if (quotation == null) return;

    final totalAmount = quotation.subtotal - discountAmount + quotation.taxAmount;
    final now = DateTime.now();

    await (update(quotations)..where((t) => t.id.equals(quotationId))).write(
      QuotationsCompanion(
        discountAmount: Value(discountAmount),
        totalAmount: Value(totalAmount),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // ==================== Convert to Sale ====================

  // Convert quotation to sale
  Future<Sale?> convertToSale({
    required String quotationId,
    required List<PaymentEntry> payments,
    bool isCredit = false,
    String? createdBy,
  }) async {
    return transaction(() async {
      final detail = await getQuotationDetail(quotationId);
      if (detail == null) return null;

      // Check if already converted
      if (detail.quotation.status == 'CONVERTED') {
        return null;
      }

      // Validate credit sales have customer
      if (isCredit && detail.quotation.customerId == null) {
        return null;
      }

      // Build cart items from quotation items
      final cartItems = <CartItem>[];
      for (final item in detail.items) {
        cartItems.add(CartItem(
          productId: item.product.id,
          productName: item.product.name,
          quantity: item.item.quantity,
          unitPrice: item.item.unitPrice,
          unitCost: item.product.weightedAvgCost,
          discountAmount: item.item.discountAmount,
          customerId: detail.quotation.customerId,
        ));
      }

      // Create sale using SalesDao
      final sale = await db.salesDao.createSale(
        cartItems: cartItems,
        customerId: detail.quotation.customerId,
        discountAmount: detail.quotation.discountAmount,
        taxAmount: detail.quotation.taxAmount,
        isCredit: isCredit,
        payments: isCredit ? null : payments,
        notes: 'Converted from quotation ${detail.quotation.quotationNumber}',
        createdBy: createdBy,
      );

      // Update quotation status
      final now = DateTime.now();
      await (update(quotations)..where((t) => t.id.equals(quotationId))).write(
        QuotationsCompanion(
          status: const Value('CONVERTED'),
          convertedSaleId: Value(sale.id),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );

      return sale;
    });
  }

  // ==================== Reports ====================

  // Get quotation summary
  Future<QuotationSummary> getQuotationSummary(DateTime startDate, DateTime endDate) async {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final allQuotations = await (select(quotations)
          ..where((t) => t.quotationDate.isBiggerOrEqualValue(startDate) &
                         t.quotationDate.isSmallerOrEqualValue(endOfDay)))
        .get();

    int total = allQuotations.length;
    int draft = 0;
    int sent = 0;
    int accepted = 0;
    int rejected = 0;
    int expired = 0;
    int converted = 0;
    double totalValue = 0;
    double convertedValue = 0;

    for (final q in allQuotations) {
      totalValue += q.totalAmount;
      switch (q.status) {
        case 'DRAFT':
          draft++;
          break;
        case 'SENT':
          sent++;
          break;
        case 'ACCEPTED':
          accepted++;
          break;
        case 'REJECTED':
          rejected++;
          break;
        case 'EXPIRED':
          expired++;
          break;
        case 'CONVERTED':
          converted++;
          convertedValue += q.totalAmount;
          break;
      }
    }

    return QuotationSummary(
      totalQuotations: total,
      draftCount: draft,
      sentCount: sent,
      acceptedCount: accepted,
      rejectedCount: rejected,
      expiredCount: expired,
      convertedCount: converted,
      totalValue: totalValue,
      convertedValue: convertedValue,
    );
  }

  // Check and update expired quotations
  Future<int> updateExpiredQuotations() async {
    final now = DateTime.now();

    final result = await (update(quotations)
      ..where((t) =>
        t.validUntil.isSmallerThanValue(now) &
        t.status.isIn(['DRAFT', 'SENT'])
      )
    ).write(
      QuotationsCompanion(
        status: const Value('EXPIRED'),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );

    return result;
  }
}

// Helper classes
class QuotationWithCustomer {
  final Quotation quotation;
  final Customer? customer;

  QuotationWithCustomer({
    required this.quotation,
    this.customer,
  });

  String get quotationNumber => quotation.quotationNumber;
  String? get customerName => customer?.name;
  double get totalAmount => quotation.totalAmount;
  String get status => quotation.status;
  DateTime get quotationDate => quotation.quotationDate;
  DateTime? get validUntil => quotation.validUntil;
  bool get isExpired => validUntil != null && validUntil!.isBefore(DateTime.now());
  bool get isConverted => quotation.convertedSaleId != null;
}

class QuotationItemWithProduct {
  final QuotationItem item;
  final Product product;

  QuotationItemWithProduct({
    required this.item,
    required this.product,
  });

  String get productName => product.name;
  String get productCode => product.code;
  int get quantity => item.quantity;
  double get unitPrice => item.unitPrice;
  double get discountAmount => item.discountAmount;
  double get totalPrice => item.totalPrice;
}

class QuotationDetail {
  final Quotation quotation;
  final Customer? customer;
  final List<QuotationItemWithProduct> items;

  QuotationDetail({
    required this.quotation,
    this.customer,
    required this.items,
  });

  String get quotationNumber => quotation.quotationNumber;
  String? get customerName => customer?.name;
  double get subtotal => quotation.subtotal;
  double get discountAmount => quotation.discountAmount;
  double get taxAmount => quotation.taxAmount;
  double get totalAmount => quotation.totalAmount;
  String get status => quotation.status;
  DateTime get quotationDate => quotation.quotationDate;
  DateTime? get validUntil => quotation.validUntil;
  int get itemCount => items.length;
  bool get isConverted => quotation.convertedSaleId != null;
  bool get canConvert => quotation.status == 'DRAFT' || quotation.status == 'ACCEPTED';
}

class QuotationSummary {
  final int totalQuotations;
  final int draftCount;
  final int sentCount;
  final int acceptedCount;
  final int rejectedCount;
  final int expiredCount;
  final int convertedCount;
  final double totalValue;
  final double convertedValue;

  QuotationSummary({
    required this.totalQuotations,
    required this.draftCount,
    required this.sentCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.expiredCount,
    required this.convertedCount,
    required this.totalValue,
    required this.convertedValue,
  });

  double get conversionRate => totalQuotations > 0 ? (convertedCount / totalQuotations) * 100 : 0;
}
