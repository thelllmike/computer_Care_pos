import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/quotation_dao.dart';
import '../../../data/local/daos/sales_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../core/database_provider.dart';
import 'sales_provider.dart' show DateRange;

// Provider for all quotations
final quotationsProvider = FutureProvider<List<QuotationWithCustomer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.quotationDao.getAllQuotations();
});

// Provider for quotations by status
final quotationsByStatusProvider = FutureProvider.family<List<QuotationWithCustomer>, QuotationStatus?>((ref, status) {
  final db = ref.watch(databaseProvider);
  if (status == null) {
    return db.quotationDao.getAllQuotations();
  }
  return db.quotationDao.getQuotationsByStatus(status);
});

// Provider for quotation detail
final quotationDetailProvider = FutureProvider.family<QuotationDetail?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.quotationDao.getQuotationDetail(id);
});

// Provider for quotation summary
final quotationSummaryProvider = FutureProvider.family<QuotationSummary, DateRange>((ref, range) {
  final db = ref.watch(databaseProvider);
  return db.quotationDao.getQuotationSummary(range.start, range.end);
});

// ==================== Quotation Form State Management ====================

class QuotationItemState {
  final String? id; // null for new items
  final String productId;
  final String productName;
  final String productCode;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final String? notes;

  QuotationItemState({
    this.id,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    this.notes,
  });

  double get lineTotal => (unitPrice * quantity) - discountAmount;

  QuotationItemState copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productCode,
    int? quantity,
    double? unitPrice,
    double? discountAmount,
    String? notes,
  }) {
    return QuotationItemState(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      notes: notes ?? this.notes,
    );
  }
}

class QuotationFormState {
  final String? quotationId; // null for new quotation
  final String? customerId;
  final String? customerName;
  final DateTime? validUntil;
  final List<QuotationItemState> items;
  final double discountAmount;
  final double taxAmount;
  final String? notes;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  QuotationFormState({
    this.quotationId,
    this.customerId,
    this.customerName,
    this.validUntil,
    this.items = const [],
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.notes,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  double get total => subtotal - discountAmount + taxAmount;
  int get itemCount => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isEditing => quotationId != null;

  QuotationFormState copyWith({
    String? quotationId,
    String? customerId,
    String? customerName,
    DateTime? validUntil,
    List<QuotationItemState>? items,
    double? discountAmount,
    double? taxAmount,
    String? notes,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearCustomer = false,
    bool clearQuotationId = false,
  }) {
    return QuotationFormState(
      quotationId: clearQuotationId ? null : (quotationId ?? this.quotationId),
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      validUntil: validUntil ?? this.validUntil,
      items: items ?? this.items,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

// Quotation Form Notifier
class QuotationFormNotifier extends StateNotifier<QuotationFormState> {
  final AppDatabase _db;
  final Ref _ref;

  QuotationFormNotifier(this._db, this._ref) : super(QuotationFormState(
    validUntil: DateTime.now().add(const Duration(days: 30)),
  ));

  // Load existing quotation for editing
  Future<void> loadQuotation(String quotationId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final detail = await _db.quotationDao.getQuotationDetail(quotationId);
      if (detail == null) {
        state = state.copyWith(isLoading: false, error: 'Quotation not found');
        return;
      }

      state = QuotationFormState(
        quotationId: detail.quotation.id,
        customerId: detail.quotation.customerId,
        customerName: detail.customer?.name,
        validUntil: detail.quotation.validUntil,
        items: detail.items.map((item) => QuotationItemState(
          id: item.item.id,
          productId: item.product.id,
          productName: item.product.name,
          productCode: item.product.code,
          quantity: item.item.quantity,
          unitPrice: item.item.unitPrice,
          discountAmount: item.item.discountAmount,
          notes: item.item.notes,
        )).toList(),
        discountAmount: detail.quotation.discountAmount,
        taxAmount: detail.quotation.taxAmount,
        notes: detail.quotation.notes,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Set customer
  void setCustomer(String? customerId, String? customerName) {
    state = state.copyWith(
      customerId: customerId,
      customerName: customerName,
      clearCustomer: customerId == null,
    );
  }

  // Set valid until date
  void setValidUntil(DateTime? validUntil) {
    state = state.copyWith(validUntil: validUntil);
  }

  // Add item
  void addItem({
    required String productId,
    required String productName,
    required String productCode,
    required double unitPrice,
    int quantity = 1,
  }) {
    // Check if product already in list
    final existingIndex = state.items.indexWhere((i) => i.productId == productId);

    if (existingIndex >= 0) {
      // Increment quantity
      final existingItem = state.items[existingIndex];
      final updatedItem = existingItem.copyWith(quantity: existingItem.quantity + quantity);
      final updatedItems = List<QuotationItemState>.from(state.items);
      updatedItems[existingIndex] = updatedItem;
      state = state.copyWith(items: updatedItems);
    } else {
      // Add new item
      final newItem = QuotationItemState(
        productId: productId,
        productName: productName,
        productCode: productCode,
        quantity: quantity,
        unitPrice: unitPrice,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  // Update item quantity
  void updateItemQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
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
  void updateItemPrice(String productId, double price) {
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

  // Remove item
  void removeItem(String productId) {
    final updatedItems = state.items.where((item) => item.productId != productId).toList();
    state = state.copyWith(items: updatedItems);
  }

  // Set quotation discount
  void setDiscount(double discount) {
    state = state.copyWith(discountAmount: discount);
  }

  // Set notes
  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  // Save quotation
  Future<Quotation?> saveQuotation({String? createdBy}) async {
    if (state.isEmpty) {
      state = state.copyWith(error: 'Please add at least one item');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      Quotation quotation;

      if (state.isEditing) {
        // Update existing quotation
        await _db.quotationDao.updateQuotation(
          id: state.quotationId!,
          customerId: state.customerId,
          validUntil: state.validUntil,
          notes: state.notes,
          clearCustomer: state.customerId == null,
        );

        // Get existing items
        final existingItems = await _db.quotationDao.getQuotationItems(state.quotationId!);
        final existingItemIds = existingItems.map((e) => e.item.id).toSet();

        // Update or add items
        for (final item in state.items) {
          if (item.id != null && existingItemIds.contains(item.id)) {
            // Update existing item
            await _db.quotationDao.updateQuotationItem(
              itemId: item.id!,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discountAmount: item.discountAmount,
              notes: item.notes,
            );
            existingItemIds.remove(item.id);
          } else {
            // Add new item
            await _db.quotationDao.addQuotationItem(
              quotationId: state.quotationId!,
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              discountAmount: item.discountAmount,
              notes: item.notes,
            );
          }
        }

        // Remove items that are no longer in the list
        for (final itemId in existingItemIds) {
          await _db.quotationDao.removeQuotationItem(itemId);
        }

        // Apply discount
        await _db.quotationDao.applyQuotationDiscount(state.quotationId!, state.discountAmount);

        quotation = (await _db.quotationDao.getQuotationById(state.quotationId!))!;
      } else {
        // Create new quotation
        quotation = await _db.quotationDao.createQuotation(
          customerId: state.customerId,
          validUntil: state.validUntil,
          notes: state.notes,
          createdBy: createdBy,
        );

        // Add items
        for (final item in state.items) {
          await _db.quotationDao.addQuotationItem(
            quotationId: quotation.id,
            productId: item.productId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            discountAmount: item.discountAmount,
            notes: item.notes,
          );
        }

        // Apply discount
        if (state.discountAmount > 0) {
          await _db.quotationDao.applyQuotationDiscount(quotation.id, state.discountAmount);
        }

        quotation = (await _db.quotationDao.getQuotationById(quotation.id))!;
      }

      // Invalidate providers
      _ref.invalidate(quotationsProvider);

      state = state.copyWith(isSaving: false);
      return quotation;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  // Clear form
  void clear() {
    state = QuotationFormState(
      validUntil: DateTime.now().add(const Duration(days: 30)),
    );
  }
}

// Quotation form provider
final quotationFormProvider = StateNotifierProvider<QuotationFormNotifier, QuotationFormState>((ref) {
  final db = ref.watch(databaseProvider);
  return QuotationFormNotifier(db, ref);
});

// ==================== Convert to Sale State ====================

class ConvertToSaleState {
  final bool isProcessing;
  final bool isSuccess;
  final String? error;
  final Sale? completedSale;

  ConvertToSaleState({
    this.isProcessing = false,
    this.isSuccess = false,
    this.error,
    this.completedSale,
  });

  ConvertToSaleState copyWith({
    bool? isProcessing,
    bool? isSuccess,
    String? error,
    Sale? completedSale,
  }) {
    return ConvertToSaleState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      completedSale: completedSale ?? this.completedSale,
    );
  }
}

class ConvertToSaleNotifier extends StateNotifier<ConvertToSaleState> {
  final AppDatabase _db;
  final Ref _ref;

  ConvertToSaleNotifier(this._db, this._ref) : super(ConvertToSaleState());

  Future<void> convertToSale({
    required String quotationId,
    required List<PaymentEntry> payments,
    bool isCredit = false,
    String? createdBy,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final sale = await _db.quotationDao.convertToSale(
        quotationId: quotationId,
        payments: payments,
        isCredit: isCredit,
        createdBy: createdBy,
      );

      if (sale == null) {
        state = state.copyWith(
          isProcessing: false,
          error: 'Failed to convert quotation. It may already be converted or invalid.',
        );
        return;
      }

      // Invalidate providers
      _ref.invalidate(quotationsProvider);

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
    state = ConvertToSaleState();
  }
}

final convertToSaleProvider = StateNotifierProvider<ConvertToSaleNotifier, ConvertToSaleState>((ref) {
  final db = ref.watch(databaseProvider);
  return ConvertToSaleNotifier(db, ref);
});
