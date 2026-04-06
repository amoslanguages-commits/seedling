import 'package:flutter/foundation.dart';
import 'dart:async';
import '../core/supabase_config.dart';
import 'auth_service.dart';
import '../database/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ================ SUBSCRIPTION SERVICE ================

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final _subscriptionController =
      StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get subscriptionStatus =>
      _subscriptionController.stream;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

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

  Future<void> checkSubscription() async {
    try {
      final userId = AuthService().userId;
      if (userId == null) return;

      final response = await SupabaseConfig.client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['status'] == 'active') {
        _isPremium = true;
        _subscriptionController.add(SubscriptionStatus.premium);
        await DatabaseHelper().updatePremiumStatus(true);
      } else {
        _isPremium = false;
        _subscriptionController.add(SubscriptionStatus.free);
        await DatabaseHelper().updatePremiumStatus(false);
      }
    } catch (e) {
      debugPrint('Subscription check error: $e');
      // Fallback to local DB
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

  Future<void> upgradeToPremium(String planId) async {
    try {
      final userId = AuthService().userId;
      if (userId == null) throw Exception('Must be logged in to upgrade');

      // In a real app, this would involve a payment gateway
      // Here we'll just update the database
      await SupabaseConfig.client.from('subscriptions').upsert({
        'user_id': userId,
        'status': 'active',
        'plan_id': planId,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _isPremium = true;
      _subscriptionController.add(SubscriptionStatus.premium);
      await DatabaseHelper().updatePremiumStatus(true);
    } catch (e) {
      throw Exception('Upgrade failed: $e');
    }
  }
}

enum SubscriptionStatus { free, premium }
