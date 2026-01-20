import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged.map((result) {
    // Convert single result to list for backwards compatibility
    return [result];
  });
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.any((result) =>
        result != ConnectivityResult.none),
    loading: () => true, // Assume online while checking
    error: (_, __) => false,
  );
});
