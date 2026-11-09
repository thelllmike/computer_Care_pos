import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/online_order_model.dart';
import '../../../data/services/online_delivery_service.dart';
import '../auth/auth_provider.dart';
import '../core/supabase_provider.dart';

// ──────────────────────────────────────────────────────────────
// Service provider
// ──────────────────────────────────────────────────────────────
final onlineDeliveryServiceProvider = Provider<OnlineDeliveryService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return OnlineDeliveryService(client);
});

// ──────────────────────────────────────────────────────────────
// Refresh trigger — bumped after every mutation
// ──────────────────────────────────────────────────────────────
final onlineOrdersRefreshProvider = StateProvider<int>((ref) => 0);

// ──────────────────────────────────────────────────────────────
// Screen-level filter providers (file-scoped via provider)
// ──────────────────────────────────────────────────────────────
final onlineOrderStatusFilterProvider = StateProvider<String?>((ref) => null);
final onlineOrderSearchQueryProvider = StateProvider<String>((ref) => '');

// ──────────────────────────────────────────────────────────────
// Orders list
// ──────────────────────────────────────────────────────────────
final onlineOrdersProvider =
    FutureProvider<List<OnlineOrderModel>>((ref) async {
  ref.watch(onlineOrdersRefreshProvider);
  final service = ref.watch(onlineDeliveryServiceProvider);
  final status = ref.watch(onlineOrderStatusFilterProvider);
  final search = ref.watch(onlineOrderSearchQueryProvider);
  return service.fetchOrders(status: status, search: search);
});

// ──────────────────────────────────────────────────────────────
// Single order detail — family provider
// ──────────────────────────────────────────────────────────────
final onlineOrderDetailProvider =
    FutureProvider.family<OnlineOrderModel?, String>((ref, id) async {
  ref.watch(onlineOrdersRefreshProvider);
  final service = ref.watch(onlineDeliveryServiceProvider);
  return service.fetchOrderById(id);
});

// ──────────────────────────────────────────────────────────────
// Action notifier state
// ──────────────────────────────────────────────────────────────
class OnlineOrderActionState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final Map<String, dynamic>? resultData;

  const OnlineOrderActionState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.resultData,
  });

  OnlineOrderActionState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    Map<String, dynamic>? resultData,
  }) {
    return OnlineOrderActionState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      resultData: resultData ?? this.resultData,
    );
  }

  OnlineOrderActionState reset() => const OnlineOrderActionState();
}

// ──────────────────────────────────────────────────────────────
// Action notifier
// ──────────────────────────────────────────────────────────────
class OnlineOrderActionNotifier
    extends StateNotifier<OnlineOrderActionState> {
  final OnlineDeliveryService _service;
  final Ref _ref;

  OnlineOrderActionNotifier(this._service, this._ref)
      : super(const OnlineOrderActionState());

  // Create order
  Future<OnlineOrderModel?> createOrder({
    required String? customerId,
    required String? customerName,
    required String? customerPhone,
    required String customerAddress,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double totalAmount,
    required double totalCost,
    required double grossProfit,
    required double deliveryFee,
    required bool isPrepaid,
    required double paidAmount,
    required String paymentMethod,
    String? notes,
    required List<Map<String, dynamic>> itemsData,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId =
          _ref.read(authNotifierProvider).user?.id ?? '';
      final order = await _service.createOrder(
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        subtotal: subtotal,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        totalAmount: totalAmount,
        totalCost: totalCost,
        grossProfit: grossProfit,
        deliveryFee: deliveryFee,
        isPrepaid: isPrepaid,
        paidAmount: paidAmount,
        paymentMethod: paymentMethod,
        notes: notes,
        createdBy: userId,
        itemsData: itemsData,
      );
      _ref.read(onlineOrdersRefreshProvider.notifier).state++;
      state = state.copyWith(isLoading: false, isSuccess: true);
      return order;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // Update status (simple transitions)
  Future<void> updateStatus(String orderId, String newStatus) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.updateOrderStatus(orderId, newStatus);
      _ref.read(onlineOrdersRefreshProvider.notifier).state++;
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Assign serials
  Future<void> assignSerials(
    String orderId,
    String itemId,
    List<Map<String, String>> serials,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.assignSerials(orderId, itemId, serials);
      _ref.read(onlineOrdersRefreshProvider.notifier).state++;
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Mark as Shipped (calls RPC)
  Future<void> markShipped(String orderId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId =
          _ref.read(authNotifierProvider).user?.id ?? '';
      final result = await _service.markShipped(orderId, userId);
      _ref.read(onlineOrdersRefreshProvider.notifier).state++;
      state = state.copyWith(
          isLoading: false, isSuccess: true, resultData: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Mark as Delivered (calls RPC)
  Future<void> markDelivered(String orderId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId =
          _ref.read(authNotifierProvider).user?.id ?? '';
      final result = await _service.markDelivered(orderId, userId);
      _ref.read(onlineOrdersRefreshProvider.notifier).state++;
      state = state.copyWith(
          isLoading: false, isSuccess: true, resultData: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = const OnlineOrderActionState();
  }
}

final onlineOrderActionProvider = StateNotifierProvider<
    OnlineOrderActionNotifier, OnlineOrderActionState>((ref) {
  final service = ref.watch(onlineDeliveryServiceProvider);
  return OnlineOrderActionNotifier(service, ref);
});
