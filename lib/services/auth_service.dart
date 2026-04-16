import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../database/database_helper.dart';
import 'sync_manager.dart';

// ================ AUTHENTICATION SERVICE ================

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _authStateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  User? get currentUser => SupabaseConfig.client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get userId => currentUser?.id;

  Future<void> initialize() async {
    // Listen to auth state changes
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      _authStateController.add(data);
    });

    // Seed the initial state
    final session = SupabaseConfig.client.auth.currentSession;
    _authStateController.add(
      AuthState(
        session == null
            ? AuthChangeEvent.signedOut
            : AuthChangeEvent.initialSession,
        session,
      ),
    );
  }

  // Email/Password Sign Up
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
        emailRedirectTo: 'https://seedlinglanguages.com/welcome.html',
      );

      if (response.user != null) {
        // NOTE: Profiles and other user records are now created automatically 
        // by the database trigger 'on_auth_user_created'.
        
        // Link any onboarding data to this new user (local DB operation)
        await DatabaseHelper().linkAnonymousDataToUser(response.user!.id);
        
        // Push local onboarding data to cloud if user is signed in
        if (SupabaseConfig.client.auth.currentSession != null) {
          SyncManager().syncToCloud();
        }
      }

      return response;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Email/Password Sign In
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        
        // Link any pre-auth data
        await DatabaseHelper().linkAnonymousDataToUser(userId);

        // Sync in background to not block the UI
        SyncManager().syncFromCloud().then((_) {
          SyncManager().syncToCloud();
        });
      }

      return response;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Google Sign In
  Future<AuthResponse> signInWithGoogle() async {
    try {
      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.seedling.app://callback',
      );

      return AuthResponse();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Apple Sign In
  Future<AuthResponse> signInWithApple() async {
    try {
      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.seedling.app://callback',
      );

      return AuthResponse();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Anonymous Sign In (for offline-first experience)
  Future<AuthResponse> signInAnonymously() async {
    try {
      final response = await SupabaseConfig.client.auth.signInAnonymously();
      return response;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    // Sync before sign out
    if (isAuthenticated) {
      await SyncManager().syncToCloud();
    }

    await SupabaseConfig.client.auth.signOut();
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      if (!isAuthenticated) return;

      // Call the secure RPC function to delete the user
      await SupabaseConfig.client.rpc('delete_user');

      // Locally sign out just in case the server-side delete didn't propagate the session kill immediately
      await SupabaseConfig.client.auth.signOut();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Password Reset
  Future<void> resetPassword(String email) async {
    await SupabaseConfig.client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://seedlinglanguages.com/reset-password.html',
    );
  }

  // Create user profile in database
  Future<void> _createUserProfile(
    String userId,
    String displayName,
    String email,
  ) async {
    // We use upsert here as a fallback in case the database trigger hasn't fired yet
    // or if we need to update existing details from the app side.
    await SupabaseConfig.client.from('profiles').upsert({
      'id': userId,
      'display_name': displayName,
      'email': email,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Exception _handleAuthError(dynamic error) {
    if (error is AuthException) {
      return Exception(error.message);
    }
    return Exception('Authentication failed. Please try again.');
  }
}
