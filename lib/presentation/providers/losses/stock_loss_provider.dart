import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/daos/stock_loss_dao.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/local/tables/stock_losses_table.dart';
import '../core/database_provider.dart';
import '../expenses/expense_provider.dart';

// DAO provider
final stockLossDaoProvider = Provider<StockLossDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.stockLossDao;
});

// Provider for all stock losses
final stockLossesProvider = FutureProvider<List<StockLossWithProduct>>((ref) {
  final dao = ref.watch(stockLossDaoProvider);
  return dao.getAllStockLosses();
});

// Provider for stock losses by date range
final stockLossesByDateRangeProvider =
    FutureProvider.family<List<StockLossWithProduct>, DateRangeParams>(
        (ref, params) {
  final dao = ref.watch(stockLossDaoProvider);
  return dao.getStockLossesByDateRange(params.startDate, params.endDate);
});

// Provider for stock losses by type
final stockLossesByTypeProvider =
    FutureProvider.family<List<StockLossWithProduct>, LossType>((ref, type) {
  final dao = ref.watch(stockLossDaoProvider);
  return dao.getStockLossesByType(type);
});

// Provider for stock loss summary (for P&L)
final stockLossSummaryProvider =
    FutureProvider.family<StockLossSummary, DateRangeParams>((ref, params) {
  final dao = ref.watch(stockLossDaoProvider);
  return dao.getLossSummary(params.startDate, params.endDate);
});

// ==================== Stock Loss Form State ====================

class StockLossFormState {
  final String? productId;
  final String? productName;
  final int quantity;
  final String? serialNumberId;
  final String? serialNumber;
  final LossType lossType;
  final String lossReason;
  final double unitCost;
  final DateTime lossDate;
  final String? notes;
  final bool isSaving;
  final String? error;

  StockLossFormState({
    this.productId,
    this.productName,
    this.quantity = 1,
    this.serialNumberId,
    this.serialNumber,
    this.lossType = LossType.damaged,
    this.lossReason = '',
    this.unitCost = 0,
    DateTime? lossDate,
    this.notes,
    this.isSaving = false,
    this.error,
  }) : lossDate = lossDate ?? DateTime.now();

  bool get isValid =>
      productId != null &&
      productId!.isNotEmpty &&
      quantity > 0 &&
      lossReason.isNotEmpty &&
      unitCost > 0;

  double get totalLossAmount => unitCost * quantity;

  StockLossFormState copyWith({
    String? productId,
    String? productName,
    int? quantity,
    String? serialNumberId,
    String? serialNumber,
    LossType? lossType,
    String? lossReason,
    double? unitCost,
    DateTime? lossDate,
    String? notes,
    bool? isSaving,
    String? error,
  }) {
    return StockLossFormState(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      serialNumberId: serialNumberId ?? this.serialNumberId,
      serialNumber: serialNumber ?? this.serialNumber,
      lossType: lossType ?? this.lossType,
      lossReason: lossReason ?? this.lossReason,
      unitCost: unitCost ?? this.unitCost,
      lossDate: lossDate ?? this.lossDate,
      notes: notes ?? this.notes,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class StockLossFormNotifier extends StateNotifier<StockLossFormState> {
  final AppDatabase _db;
  final Ref _ref;

  StockLossFormNotifier(this._db, this._ref) : super(StockLossFormState());

  void setProduct(String productId, String productName, double unitCost) {
    state = state.copyWith(
      productId: productId,
      productName: productName,
      unitCost: unitCost,
      serialNumberId: null,
      serialNumber: null,
    );
  }

  void setSerialNumber(String? serialId, String? serialNumber, double? unitCost) {
    state = state.copyWith(
      serialNumberId: serialId,
      serialNumber: serialNumber,
      unitCost: unitCost ?? state.unitCost,
      quantity: serialId != null ? 1 : state.quantity, // Serialized items are always qty 1
    );
  }

  void setQuantity(int quantity) {
    state = state.copyWith(quantity: quantity);
  }

  void setLossType(LossType type) {
    state = state.copyWith(lossType: type);
  }

  void setLossReason(String reason) {
    state = state.copyWith(lossReason: reason);
  }

  void setUnitCost(double cost) {
    state = state.copyWith(unitCost: cost);
  }

  void setLossDate(DateTime date) {
    state = state.copyWith(lossDate: date);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  Future<StockLossesData?> saveStockLoss({String? createdBy}) async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Please fill in all required fields');
      return null;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final stockLoss = await _db.stockLossDao.createStockLoss(
        productId: state.productId!,
        quantity: state.quantity,
        serialNumberId: state.serialNumberId,
        lossType: state.lossType,
        lossReason: state.lossReason,
        unitCost: state.unitCost,
        lossDate: state.lossDate,
        notes: state.notes,
        createdBy: createdBy,
      );

      // Invalidate providers
      _ref.invalidate(stockLossesProvider);

      state = state.copyWith(isSaving: false);
      return stockLoss;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  void clear() {
    state = StockLossFormState();
  }
}

final stockLossFormProvider =
    StateNotifierProvider<StockLossFormNotifier, StockLossFormState>((ref) {
  final db = ref.watch(databaseProvider);
  return StockLossFormNotifier(db, ref);
});

// Delete stock loss provider
final deleteStockLossProvider =
    FutureProvider.family<void, String>((ref, id) async {
  final dao = ref.watch(stockLossDaoProvider);
  await dao.deleteStockLoss(id);
  ref.invalidate(stockLossesProvider);
});
