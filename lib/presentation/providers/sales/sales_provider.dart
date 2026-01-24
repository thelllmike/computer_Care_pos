import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/sales_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';

// Provider for all sales
final salesProvider = StreamProvider<List<SaleWithCustomer>>((ref) {
  final db = ref.watch(databaseProvider);
  return Stream.fromFuture(db.salesDao.getAllSales());
});

// Provider for today's sales
final todaysSalesProvider = FutureProvider<List<SaleWithCustomer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.salesDao.getTodaysSales();
});

// Provider for sale detail
final saleDetailProvider = FutureProvider.family<SaleDetail?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.salesDao.getSaleDetail(id);
});

// Provider for sales summary
final salesSummaryProvider = FutureProvider.family<SalesSummary, DateRange>((ref, range) {
  final db = ref.watch(databaseProvider);
  return db.salesDao.getSalesSummary(range.start, range.end);
});

// Date range helper
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  factory DateRange.today() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  factory DateRange.thisMonth() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange &&
        other.start.year == start.year &&
        other.start.month == start.month &&
        other.start.day == start.day &&
        other.end.year == end.year &&
        other.end.month == end.month &&
        other.end.day == end.day;
  }

  @override
  int get hashCode => Object.hash(
        start.year,
        start.month,
        start.day,
        end.year,
        end.month,
        end.day,
      );
}

// ==================== Cart State Management ====================

class CartItemState {
  final String productId;
  final String productName;
  final String productCode;
  final int quantity;
  final double unitPrice;
  final double unitCost;
  final double discountAmount;
  final bool trackSerials;
  final List<SelectedSerial> selectedSerials;

  CartItemState({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    this.discountAmount = 0,
    required this.trackSerials,
    this.selectedSerials = const [],
  });

  double get lineTotal => (unitPrice * quantity) - discountAmount;
  double get lineCost => unitCost * quantity;
  double get lineProfit => lineTotal - lineCost;

  CartItemState copyWith({
    int? quantity,
    double? unitPrice,
    double? discountAmount,
    List<SelectedSerial>? selectedSerials,
  }) {
    return CartItemState(
      productId: productId,
      productName: productName,
      productCode: productCode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost,
      discountAmount: discountAmount ?? this.discountAmount,
      trackSerials: trackSerials,
      selectedSerials: selectedSerials ?? this.selectedSerials,
    );
  }
}

class SelectedSerial {
  final String id;
  final String serialNumber;
  final double unitCost;

  SelectedSerial({
    required this.id,
    required this.serialNumber,
    required this.unitCost,
  });
}

class CartState {
  final List<CartItemState> items;
  final String? customerId;
  final String? customerName;
  final double discountAmount;
  final double taxAmount;
  final bool isCredit;
  final String? notes;

  CartState({
    this.items = const [],
    this.customerId,
    this.customerName,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.isCredit = false,
    this.notes,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  double get totalCost => items.fold(0, (sum, item) => sum + item.lineCost);
  double get total => subtotal - discountAmount + taxAmount;
  double get totalProfit => subtotal - totalCost - discountAmount;
  int get itemCount => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
  bool get hasSerializedItems => items.any((i) => i.trackSerials);

  CartState copyWith({
    List<CartItemState>? items,
    String? customerId,
    String? customerName,
    double? discountAmount,
    double? taxAmount,
    bool? isCredit,
    String? notes,
    bool clearCustomer = false,
  }) {
    return CartState(
      items: items ?? this.items,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      isCredit: isCredit ?? this.isCredit,
      notes: notes ?? this.notes,
    );
  }
}

// Cart Notifier
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  // Add product to cart
  void addProduct({
    required String productId,
    required String productName,
    required String productCode,
    required double unitPrice,
    required double unitCost,
    required bool trackSerials,
    int quantity = 1,
  }) {
    // Check if product already in cart
    final existingIndex = state.items.indexWhere((i) => i.productId == productId);

    if (existingIndex >= 0 && !trackSerials) {
      // Increment quantity for non-serialized products
      final existingItem = state.items[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );

      final updatedItems = List<CartItemState>.from(state.items);
      updatedItems[existingIndex] = updatedItem;

      state = state.copyWith(items: updatedItems);
    } else {
      // Add new item
      final newItem = CartItemState(
        productId: productId,
        productName: productName,
        productCode: productCode,
        quantity: trackSerials ? 0 : quantity, // Serialized products need serial selection
        unitPrice: unitPrice,
        unitCost: unitCost,
        trackSerials: trackSerials,
      );

      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  // Update item quantity
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  // Update item price
  void updatePrice(String productId, double price) {
    final updatedItems = state.items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(unitPrice: price);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  // Update item discount
  void updateItemDiscount(String productId, double discount) {
    final updatedItems = state.items.map((item) {
      if (item.productId == productId) {
        return item.copyWith(discountAmount: discount);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  // Add serial to item
  void addSerial(String productId, SelectedSerial serial) {
    final updatedItems = state.items.map((item) {
      if (item.productId == productId) {
        final updatedSerials = [...item.selectedSerials, serial];
        return item.copyWith(
          selectedSerials: updatedSerials,
          quantity: updatedSerials.length,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  // Remove serial from item
  void removeSerial(String productId, String serialId) {
    final updatedItems = state.items.map((item) {
      if (item.productId == productId) {
        final updatedSerials = item.selectedSerials
            .where((s) => s.id != serialId)
            .toList();
        return item.copyWith(
          selectedSerials: updatedSerials,
          quantity: updatedSerials.length,
        );
      }
      return item;
    }).toList();

    // Remove item if no serials left
    final filteredItems = updatedItems.where((item) {
      if (item.trackSerials && item.selectedSerials.isEmpty) {
        return false;
      }
      return true;
    }).toList();

    state = state.copyWith(items: filteredItems);
  }

  // Remove product from cart
  void removeProduct(String productId) {
    final updatedItems = state.items
        .where((item) => item.productId != productId)
        .toList();

    state = state.copyWith(items: updatedItems);
  }

  // Set customer
  void setCustomer(String? customerId, String? customerName) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
      clearCustomer: customerId == null,
    );
  }

  // Set cart discount
  void setDiscount(double discount) {
    state = state.copyWith(discountAmount: discount);
  }

  // Set tax
  void setTax(double tax) {
    state = state.copyWith(taxAmount: tax);
  }

  // Set credit sale
  void setIsCredit(bool isCredit) {
    state = state.copyWith(isCredit: isCredit);
  }

  // Set notes
  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  // Clear cart
  void clear() {
    state = CartState();
  }
}

// Cart provider
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// ==================== Checkout State ====================

class CheckoutState {
  final bool isProcessing;
  final bool isSuccess;
  final String? error;
  final Sale? completedSale;

  CheckoutState({
    this.isProcessing = false,
    this.isSuccess = false,
    this.error,
    this.completedSale,
  });

  CheckoutState copyWith({
    bool? isProcessing,
    bool? isSuccess,
    String? error,
    Sale? completedSale,
  }) {
    return CheckoutState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      completedSale: completedSale ?? this.completedSale,
    );
  }
}

// Checkout notifier
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final AppDatabase _db;
  final Ref _ref;

  CheckoutNotifier(this._db, this._ref) : super(CheckoutState());

  Future<void> completeSale({
    required List<PaymentEntry> payments,
    String? createdBy,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final cart = _ref.read(cartProvider);

      if (cart.isEmpty) {
        state = state.copyWith(isProcessing: false, error: 'Cart is empty');
        return;
      }

      // Validate serialized items have serials selected
      for (final item in cart.items) {
        if (item.trackSerials && item.selectedSerials.isEmpty) {
          state = state.copyWith(
            isProcessing: false,
            error: 'Please select serial numbers for ${item.productName}',
          );
          return;
        }
      }

      // Validate credit sales have a customer
      if (cart.isCredit && cart.customerId == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Credit sales require a customer',
        );
        return;
      }

      // Convert cart items to DAO format
      final cartItems = cart.items.map((item) {
        // Calculate actual cost for serialized items
        double actualUnitCost = item.unitCost;
        if (item.trackSerials && item.selectedSerials.isNotEmpty) {
          actualUnitCost = item.selectedSerials.fold(0.0, (sum, s) => sum + s.unitCost) /
              item.selectedSerials.length;
        }

        return CartItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          unitCost: actualUnitCost,
          discountAmount: item.discountAmount,
          serialNumbers: item.trackSerials
              ? item.selectedSerials.map((s) => s.id).toList()
              : null,
          customerId: cart.customerId,
        );
      }).toList();

      // Create sale
      final sale = await _db.salesDao.createSale(
        cartItems: cartItems,
        customerId: cart.customerId,
        discountAmount: cart.discountAmount,
        taxAmount: cart.taxAmount,
        isCredit: cart.isCredit,
        payments: cart.isCredit ? null : payments,
        notes: cart.notes,
        createdBy: createdBy,
      );

      // Clear cart
      _ref.read(cartProvider.notifier).clear();

      // Invalidate providers
      _ref.invalidate(salesProvider);
      _ref.invalidate(todaysSalesProvider);
      _ref.invalidate(salesSummaryProvider(DateRange.today()));

      state = state.copyWith(
        isProcessing: false,
        isSuccess: true,
        completedSale: sale,
      );
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
    }
  }

  void reset() {
    state = CheckoutState();
  }
}

// Checkout provider
final checkoutProvider = StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
  final db = ref.watch(databaseProvider);
  return CheckoutNotifier(db, ref);
});
