import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import '../core/supabase_config.dart';
import 'auth_service.dart';
import '../database/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================ SUBSCRIPTION SERVICE ================
//
// Security model:
//   • The app NEVER writes to the subscriptions table directly.
//   • All writes go through Supabase Edge Functions (server-side).
//   • Edge Functions verify payment receipts before granting premium.
//   • The app only READS the subscriptions table (own row via RLS).

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final _supabase = SupabaseConfig.client;

  final _subscriptionController =
      StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get subscriptionStatus =>
      _subscriptionController.stream;

  final _paymentController = StreamController<String>.broadcast();
  Stream<String> get paymentStatusStream => _paymentController.stream;

  /// Yields [isPremium] immediately, then every live update.
  Stream<bool> get premiumStateStream async* {
    yield _isPremium;
    await for (final status in subscriptionStatus) {
      yield status == SubscriptionStatus.premium;
    }
  }

  bool _isPremium = false;
  bool get isPremium => _isPremium;
  
  bool _isGracePeriod = false;
  bool get isGracePeriod => _isGracePeriod;

  /// Re-fetch entitlement from Supabase. Safe to call after returning from checkout.
  Future<void> refreshSubscription() => checkSubscription();

  Future<void> initialize() async {
    if (AuthService().isAuthenticated) {
      await checkSubscription();
    }

    AuthService().authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        checkSubscription();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _isPremium = false;
        _subscriptionController.add(SubscriptionStatus.free);
      }
    });
  }

  /// Reads the subscription row from Supabase — never trusts local cache alone.
  Future<void> checkSubscription() async {
    try {
      final userId = AuthService().userId;
      if (userId == null) return;

      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && (response['status'] == 'active' || response['status'] == 'past_due')) {
        _isPremium = true;
        _isGracePeriod = response['status'] == 'past_due';
        _subscriptionController.add(SubscriptionStatus.premium);
        _paymentController.add(response['status']);
        await DatabaseHelper().updatePremiumStatus(true);
      } else {
        _isPremium = false;
        _isGracePeriod = false;
        _subscriptionController.add(SubscriptionStatus.free);
        await DatabaseHelper().updatePremiumStatus(false);
      }
    } catch (e) {
      debugPrint('Subscription check error: $e');
      // Fallback to local DB if Supabase is unreachable
      final db = await DatabaseHelper().database;
      final result = await db.query('user_progress', columns: ['is_premium']);
      if (result.isNotEmpty) {
        _isPremium = result.first['is_premium'] == 1;
        _subscriptionController.add(
          _isPremium ? SubscriptionStatus.premium : SubscriptionStatus.free,
        );
      }
    }
  }

  // ── Checkout Methods (Zero-Trust) ───────────────────

  /// Fetches the recommended payment configuration based on the user's geolocation.
  /// Uses a stale-while-revalidate pattern for zero-latency UI.
  Future<Map<String, dynamic>> getPaymentConfig() async {
    // 1. Return cached config immediately if available
    final cachedStr = await DatabaseHelper().getAppConfig('payment_config');
    Map<String, dynamic>? cachedConfig;
    if (cachedStr != null) {
      try {
        cachedConfig = jsonDecode(cachedStr) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 2. Fetch fresh config in the background
    final freshFetch = _invokeEdgeFunction('payment-config', {}).then((data) {
      DatabaseHelper().setAppConfig('payment_config', jsonEncode(data));
      return data;
    });

    // 3. Return cached or wait for fresh
    return cachedConfig ?? await freshFetch;
  }

  /// Creates a Lemon Squeezy checkout session for international cards.
  Future<String> createCheckoutSession(String planId) async {
    final data = await _invokeEdgeFunction('lemon-checkout', {'plan_id': planId});
    return data['url'] as String;
  }

  /// Creates a Flutterwave checkout session for African Mobile Money.
  Future<String> createFlutterwaveCheckoutSession(String planId) async {
    final data = await _invokeEdgeFunction('flutterwave-checkout', {'plan_id': planId});
    return data['url'] as String;
  }

  /// Creates a dLocal checkout session for Asian/LATAM local payments.
  Future<String> createDLocalCheckoutSession(String planId) async {
    final data = await _invokeEdgeFunction('dlocal-checkout', {'plan_id': planId});
    return data['url'] as String;
  }

  /// Opens the Lemon Squeezy customer portal for managing subscriptions.
  Future<String> createPortalSession() async {
    final data = await _invokeEdgeFunction('lemon-portal', {});
    return data['url'] as String;
  }

  /// Internal helper to invoke any Supabase Edge Function with standard auth.
  Future<Map<String, dynamic>> _invokeEdgeFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabase.functions.invoke(functionName, body: body);
      if (response.status != 200) {
        final errMsg = response.data?['error'] ?? 'Service unavailable';
        throw SubscriptionException(errMsg);
      }
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      if (e is SubscriptionException) rethrow;
      debugPrint('EdgeFunction $functionName error: $e');
      throw const SubscriptionException('Connection failed. Please check your internet.');
    }
  }
}

enum SubscriptionStatus { free, premium }

/// Typed exception for user-facing subscription errors.
class SubscriptionException implements Exception {
  final String message;
  const SubscriptionException(this.message);
  @override
  String toString() => message;
}
