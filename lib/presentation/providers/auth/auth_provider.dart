import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums/user_role.dart';
import '../../../data/local/database/app_database.dart' hide User;
import '../core/database_provider.dart';
import '../core/supabase_provider.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final UserRole? role;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.role,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    User? user,
    UserRole? role,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      role: role ?? this.role,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabaseClient;
  final AppDatabase _database;

  AuthNotifier(this._supabaseClient, this._database) : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser != null) {
      await _loadUserData(currentUser);
    }
  }

  Future<void> _loadUserData(User user) async {
    try {
      // Try to get user role from Supabase
      final response = await _supabaseClient
          .from('users')
          .select('role')
          .eq('auth_id', user.id)
          .maybeSingle();

      UserRole role = UserRole.cashier;
      if (response != null && response['role'] != null) {
        role = UserRoleExtension.fromString(response['role'] as String);
      }

      state = AuthState(
        isAuthenticated: true,
        user: user,
        role: role,
      );
    } catch (e) {
      // If Supabase fails, check local database
      state = AuthState(
        isAuthenticated: true,
        user: user,
        role: UserRole.cashier, // Default role
      );
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserData(response.user!);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Please check your credentials.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);

    try {
      await _supabaseClient.auth.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to sign out.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  final database = ref.watch(databaseProvider);
  return AuthNotifier(supabaseClient, database);
});

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.role;
});
