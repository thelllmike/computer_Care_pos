import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/serial_status.dart';
import '../../../core/enums/payment_method.dart';
import '../database/app_database.dart';
import '../tables/sales_table.dart';
import '../tables/products_table.dart';
import '../tables/customers_table.dart';
import '../tables/inventory_table.dart';
import '../tables/serial_numbers_table.dart';
import '../tables/payments_table.dart';
import '../tables/credit_transactions_table.dart';

part 'sales_dao.g.dart';

@DriftAccessor(tables: [
  Sales, SaleItems, SaleSerials,
  Products, Customers, Inventory, SerialNumbers,
  Payments, CreditTransactions
])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

  static const _uuid = Uuid();

  // ==================== Sales Operations ====================

  // Get all sales
  Future<List<SaleWithCustomer>> getAllSales() async {
    final query = select(sales).join([
      leftOuterJoin(customers, customers.id.equalsExp(sales.customerId)),
    ])
      ..orderBy([OrderingTerm.desc(sales.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return SaleWithCustomer(
        sale: row.readTable(sales),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Get sales for today
  Future<List<SaleWithCustomer>> getTodaysSales() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = select(sales).join([
      leftOuterJoin(customers, customers.id.equalsExp(sales.customerId)),
    ])
      ..where(sales.saleDate.isBiggerOrEqualValue(startOfDay) &
              sales.saleDate.isSmallerThanValue(endOfDay))
      ..orderBy([OrderingTerm.desc(sales.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return SaleWithCustomer(
        sale: row.readTable(sales),
        customer: row.readTableOrNull(customers),
      );
    }).toList();
  }

  // Get sale by ID
  Future<Sale?> getSaleById(String id) {
    return (select(sales)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get sale detail
  Future<SaleDetail?> getSaleDetail(String id) async {
    final sale = await getSaleById(id);
    if (sale == null) return null;

    final customer = sale.customerId != null
        ? await (select(customers)..where((t) => t.id.equals(sale.customerId!))).getSingleOrNull()
        : null;

    final items = await getSaleItems(id);
    final paymentList = await getSalePayments(id);

    return SaleDetail(
      sale: sale,
      customer: customer,
      items: items,
      payments: paymentList,
    );
  }

  // Watch sale by ID
  Stream<Sale?> watchSaleById(String id) {
    return (select(sales)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  // Create sale with items
  Future<Sale> createSale({
    required List<CartItem> cartItems,
    String? customerId,
    double discountAmount = 0,
    double taxAmount = 0,
    bool isCredit = false,
    List<PaymentEntry>? payments,
    double creditAmount = 0, // Amount to be added as credit
    String? notes,
    String? createdBy,
  }) async {
    return transaction(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final invoiceNumber = await db.getNextSequenceNumber('INVOICE');

      // Calculate totals
      double subtotal = 0;
      double totalCost = 0;

      for (final item in cartItems) {
        subtotal += item.totalPrice;
        totalCost += item.totalCost;
      }

      final totalAmount = subtotal - discountAmount + taxAmount;
      final grossProfit = subtotal - totalCost - discountAmount;

      // Determine paid amount
      double paidAmount = 0;
      if (payments != null && payments.isNotEmpty) {
        paidAmount = payments.fold(0, (sum, p) => sum + p.amount);
      } else if (!isCredit && creditAmount <= 0) {
        paidAmount = totalAmount;
      }

      // Create sale record
      await into(sales).insert(SalesCompanion.insert(
        id: id,
        invoiceNumber: invoiceNumber,
        saleDate: now,
        customerId: Value(customerId),
        subtotal: Value(subtotal),
        discountAmount: Value(discountAmount),
        taxAmount: Value(taxAmount),
        totalAmount: Value(totalAmount),
        paidAmount: Value(paidAmount),
        totalCost: Value(totalCost),
        grossProfit: Value(grossProfit),
        isCredit: Value(isCredit || creditAmount > 0), // Mark as credit if any credit portion
        status: const Value('COMPLETED'),
        notes: Value(notes),
        createdBy: Value(createdBy),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ));

      // Create sale items and update inventory
      for (final cartItem in cartItems) {
        await _createSaleItem(
          saleId: id,
          cartItem: cartItem,
          createdBy: createdBy,
        );
      }

      // Create payments if any
      if (payments != null && payments.isNotEmpty) {
        for (final payment in payments) {
          await _createPayment(
            saleId: id,
            method: payment.method,
            amount: payment.amount,
            reference: payment.reference,
            createdBy: createdBy,
          );
        }
      }

      // Create credit transaction only for the credit portion
      if (creditAmount > 0 && customerId != null) {
        await _createCreditTransaction(
          customerId: customerId,
          saleId: id,
          amount: creditAmount,
          createdBy: createdBy,
        );
      }

      return (await getSaleById(id))!;
    });
  }

  // Create sale item and update inventory
  Future<void> _createSaleItem({
    required String saleId,
    required CartItem cartItem,
    String? createdBy,
  }) async {
    final itemId = _uuid.v4();
    final now = DateTime.now();

    // Insert sale item
    await into(saleItems).insert(SaleItemsCompanion.insert(
      id: itemId,
      saleId: saleId,
      productId: cartItem.productId,
      quantity: cartItem.quantity,
      unitPrice: cartItem.unitPrice,
      unitCost: cartItem.unitCost,
      totalPrice: cartItem.totalPrice,
      totalCost: cartItem.totalCost,
      profit: cartItem.profit,
      discountAmount: Value(cartItem.discountAmount),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Handle serialized products
    if (cartItem.serialNumbers != null && cartItem.serialNumbers!.isNotEmpty) {
      for (final serialId in cartItem.serialNumbers!) {
        await _createSaleSerial(
          saleItemId: itemId,
          serialId: serialId,
          saleId: saleId,
          customerId: cartItem.customerId,
          createdBy: createdBy,
        );
      }
    }

    // Update inventory
    await _updateInventoryOnSale(cartItem.productId, cartItem.quantity, cartItem.totalCost);
  }

  // Create sale serial and update serial status
  Future<void> _createSaleSerial({
    required String saleItemId,
    required String serialId,
    required String saleId,
    String? customerId,
    String? createdBy,
  }) async {
    final serial = await (select(serialNumbers)..where((t) => t.id.equals(serialId))).getSingle();
    final now = DateTime.now();
    final saleSerialId = _uuid.v4();

    // Get product for warranty
    final product = await (select(products)..where((t) => t.id.equals(serial.productId))).getSingle();
    final warrantyEnd = product.warrantyMonths > 0
        ? now.add(Duration(days: product.warrantyMonths * 30))
        : null;

    // Insert sale serial
    await into(saleSerials).insert(SaleSerialsCompanion.insert(
      id: saleSerialId,
      saleItemId: saleItemId,
      serialNumberId: serialId,
      serialNumber: serial.serialNumber,
      unitCost: serial.unitCost,
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Update serial number status
    await db.inventoryDao.updateSerialStatus(
      serialId: serialId,
      newStatus: SerialStatus.sold,
      saleId: saleId,
      customerId: customerId,
      warrantyStartDate: now,
      warrantyEndDate: warrantyEnd,
      referenceType: 'SALE',
      referenceId: saleId,
      notes: 'Sold',
      changedBy: createdBy,
    );
  }

  // Update inventory on sale
  Future<void> _updateInventoryOnSale(String productId, int quantity, double totalCost) async {
    final now = DateTime.now();
    final inv = await (select(inventory)..where((t) => t.productId.equals(productId))).getSingleOrNull();

    if (inv != null) {
      await (update(inventory)..where((t) => t.productId.equals(productId))).write(
        InventoryCompanion(
          quantityOnHand: Value(inv.quantityOnHand - quantity),
          totalCost: Value(inv.totalCost - totalCost),
          lastStockDate: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
          localUpdatedAt: Value(now),
        ),
      );
    }
  }

  // Create payment
  Future<void> _createPayment({
    required String saleId,
    required PaymentMethod method,
    required double amount,
    String? reference,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(payments).insert(PaymentsCompanion.insert(
      id: id,
      saleId: saleId,
      paymentMethod: method.code,
      amount: amount,
      paymentDate: now,
      referenceNumber: Value(reference),
      receivedBy: Value(createdBy),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));
  }

  // Create credit transaction
  Future<void> _createCreditTransaction({
    required String customerId,
    required String saleId,
    required double amount,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // Get current customer balance
    final customer = await (select(customers)..where((t) => t.id.equals(customerId))).getSingle();
    final newBalance = customer.creditBalance + amount;

    // Insert credit transaction
    await into(creditTransactions).insert(CreditTransactionsCompanion.insert(
      id: id,
      customerId: customerId,
      transactionType: 'SALE',
      amount: amount,
      balanceAfter: newBalance,
      transactionDate: now,
      referenceType: Value('SALE'),
      referenceId: Value(saleId),
      notes: Value('Credit sale'),
      createdBy: Value(createdBy),
      syncStatus: const Value('PENDING'),
      localUpdatedAt: Value(now),
    ));

    // Update customer credit balance
    await (update(customers)..where((t) => t.id.equals(customerId))).write(
      CustomersCompanion(
        creditBalance: Value(newBalance),
        updatedAt: Value(now),
        syncStatus: const Value('PENDING'),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // ==================== Sale Items ====================

  // Get sale items
  Future<List<SaleItemWithProduct>> getSaleItems(String saleId) async {
    final query = select(saleItems).join([
      innerJoin(products, products.id.equalsExp(saleItems.productId)),
    ])
      ..where(saleItems.saleId.equals(saleId))
      ..orderBy([OrderingTerm.asc(saleItems.createdAt)]);

    final results = await query.get();

    final itemsWithSerials = <SaleItemWithProduct>[];
    for (final row in results) {
      final item = row.readTable(saleItems);
      final product = row.readTable(products);
      final serials = await getSaleItemSerials(item.id);

      itemsWithSerials.add(SaleItemWithProduct(
        item: item,
        product: product,
        serials: serials,
      ));
    }

    return itemsWithSerials;
  }

  // Get serials for sale item
  Future<List<SaleSerial>> getSaleItemSerials(String saleItemId) {
    return (select(saleSerials)..where((t) => t.saleItemId.equals(saleItemId))).get();
  }

  // ==================== Payments ====================

  // Get payments for sale
  Future<List<Payment>> getSalePayments(String saleId) {
    return (select(payments)
          ..where((t) => t.saleId.equals(saleId))
          ..orderBy([(t) => OrderingTerm.asc(t.paymentDate)]))
        .get();
  }

  // ==================== Sales History ====================

  // Get sales history with filters
  Future<List<SaleWithDetails>> getSalesHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    String? searchQuery, // Invoice number search
  }) async {
    var query = select(sales).join([
      leftOuterJoin(customers, customers.id.equalsExp(sales.customerId)),
    ]);

    Expression<bool>? whereClause;

    // Date range filter
    if (startDate != null && endDate != null) {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      whereClause = sales.saleDate.isBiggerOrEqualValue(startDate) &
          sales.saleDate.isSmallerOrEqualValue(endOfDay);
    } else if (startDate != null) {
      whereClause = sales.saleDate.isBiggerOrEqualValue(startDate);
    } else if (endDate != null) {
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      whereClause = sales.saleDate.isSmallerOrEqualValue(endOfDay);
    }

    // Customer filter
    if (customerId != null) {
      final customerFilter = sales.customerId.equals(customerId);
      whereClause = whereClause != null
          ? whereClause & customerFilter
          : customerFilter;
    }

    // Invoice number search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchTerm = '%$searchQuery%';
      final searchFilter = sales.invoiceNumber.like(searchTerm);
      whereClause = whereClause != null
          ? whereClause & searchFilter
          : searchFilter;
    }

    if (whereClause != null) {
      query = query..where(whereClause);
    }

    query = query..orderBy([OrderingTerm.desc(sales.saleDate)]);

    final results = await query.get();

    final salesWithDetails = <SaleWithDetails>[];
    for (final row in results) {
      final sale = row.readTable(sales);
      final customer = row.readTableOrNull(customers);
      final paymentList = await getSalePayments(sale.id);

      salesWithDetails.add(SaleWithDetails(
        sale: sale,
        customer: customer,
        payments: paymentList,
      ));
    }

    return salesWithDetails;
  }

  // ==================== Reports ====================

  // Get sales summary for date range
  Future<SalesSummary> getSalesSummary(DateTime startDate, DateTime endDate) async {
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final allSales = await (select(sales)
          ..where((t) => t.saleDate.isBiggerOrEqualValue(startDate) &
                         t.saleDate.isSmallerOrEqualValue(endOfDay)))
        .get();

    int count = allSales.length;
    double totalRevenue = 0;
    double totalCost = 0;
    double totalProfit = 0;
    double totalCredit = 0;
    double laborIncome = 0;

    for (final sale in allSales) {
      totalRevenue += sale.totalAmount;
      totalCost += sale.totalCost;
      totalProfit += sale.grossProfit;
      if (sale.isCredit) {
        totalCredit += sale.totalAmount - sale.paidAmount;
      }

      // Get labor income from sale items (SERVICE_LABOR items from repairs)
      final laborItems = await (select(saleItems)
            ..where((i) => i.saleId.equals(sale.id) & i.productId.equals('SERVICE_LABOR')))
          .get();
      for (final item in laborItems) {
        laborIncome += item.totalPrice;
      }
    }

    return SalesSummary(
      totalSales: count,
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      totalProfit: totalProfit,
      totalCreditOutstanding: totalCredit,
      laborIncome: laborIncome,
    );
  }
}

// Helper classes
class CartItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double discountAmount;
  final List<String>? serialNumbers;
  final String? customerId;

  CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    this.discountAmount = 0,
    this.serialNumbers,
    this.customerId,
  });

  double get totalPrice => (unitPrice * quantity) - discountAmount;
  double get totalCost => unitCost * quantity;
  double get profit => totalPrice - totalCost;
}

class PaymentEntry {
  final PaymentMethod method;
  final double amount;
  final String? reference;

  PaymentEntry({
    required this.method,
    required this.amount,
    this.reference,
  });
}

class SaleWithCustomer {
  final Sale sale;
  final Customer? customer;

  SaleWithCustomer({
    required this.sale,
    this.customer,
  });

  String get invoiceNumber => sale.invoiceNumber;
  String? get customerName => customer?.name;
  double get totalAmount => sale.totalAmount;
  double get grossProfit => sale.grossProfit;
  bool get isCredit => sale.isCredit;
  DateTime get saleDate => sale.saleDate;
}

class SaleItemWithProduct {
  final SaleItem item;
  final Product product;
  final List<SaleSerial> serials;

  SaleItemWithProduct({
    required this.item,
    required this.product,
    this.serials = const [],
  });

  String get productName => product.name;
  String get productCode => product.code;
  int get quantity => item.quantity;
  double get unitPrice => item.unitPrice;
  double get totalPrice => item.totalPrice;
  double get profit => item.profit;
  bool get isSerialized => serials.isNotEmpty;
  List<String> get serialNumberList => serials.map((s) => s.serialNumber).toList();
}

class SaleDetail {
  final Sale sale;
  final Customer? customer;
  final List<SaleItemWithProduct> items;
  final List<Payment> payments;

  SaleDetail({
    required this.sale,
    this.customer,
    required this.items,
    required this.payments,
  });

  String get invoiceNumber => sale.invoiceNumber;
  String? get customerName => customer?.name;
  double get subtotal => sale.subtotal;
  double get discountAmount => sale.discountAmount;
  double get taxAmount => sale.taxAmount;
  double get totalAmount => sale.totalAmount;
  double get paidAmount => sale.paidAmount;
  double get balanceDue => sale.totalAmount - sale.paidAmount;
  double get grossProfit => sale.grossProfit;
  bool get isCredit => sale.isCredit;
  bool get isFullyPaid => balanceDue <= 0;
}

class SalesSummary {
  final int totalSales;
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double totalCreditOutstanding;
  final double laborIncome; // Repair labor/service income

  SalesSummary({
    required this.totalSales,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.totalCreditOutstanding,
    this.laborIncome = 0,
  });

  double get profitMargin => totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;
  double get productRevenue => totalRevenue - laborIncome; // Revenue from product sales only
}

class SaleWithDetails {
  final Sale sale;
  final Customer? customer;
  final List<Payment> payments;

  SaleWithDetails({
    required this.sale,
    this.customer,
    required this.payments,
  });

  String get invoiceNumber => sale.invoiceNumber;
  String? get customerName => customer?.name;
  double get totalAmount => sale.totalAmount;
  double get paidAmount => sale.paidAmount;
  double get balanceDue => sale.totalAmount - sale.paidAmount;
  bool get isCredit => sale.isCredit;
  bool get isFullyPaid => balanceDue <= 0;
  DateTime get saleDate => sale.saleDate;
  String get status => sale.status;

  String get paymentStatus {
    if (isFullyPaid) return 'Paid';
    if (paidAmount > 0) return 'Partial';
    return 'Pending';
  }
}
