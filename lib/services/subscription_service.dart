import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ransh_app/models/subscription_plan.dart';
import 'package:ransh_app/models/user_session.dart';

/// Subscription status constants
class SubscriptionStatus {
  static const String active = 'active';
  static const String expired = 'expired';
  static const String free = 'free';
}

/// Service for managing subscription verification
class SubscriptionService {
  static const String _cachedStatusKey = 'ransh_subscription_status';
  static const String _cachedExpiryKey = 'ransh_subscription_expiry';
  static const String _cacheFreshnessKey = 'ransh_subscription_cache_time';
  static const Duration _cacheValidity = Duration(hours: 24);

  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _secureStorage;

  String? _currentStatus;
  DateTime? _currentExpiry;
  String? _currentPlan;

  SubscriptionService({
    FirebaseFirestore? firestore,
    FlutterSecureStorage? secureStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Get current subscription status (cached)
  String get currentStatus => _currentStatus ?? SubscriptionStatus.free;

  /// Check if user has active subscription
  bool get hasActiveSubscription {
    if (_currentStatus != SubscriptionStatus.active) return false;
    if (_currentExpiry == null) return true;
    return _currentExpiry!.isAfter(DateTime.now());
  }

  /// Get subscription from Firestore
  Future<void> fetchSubscription(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final doc = await userRef.get();

      if (doc.exists) {
        final data = doc.data();
        _currentStatus =
            data?['subscription_status'] as String? ?? SubscriptionStatus.free;

        // Support both field names (app writes 'subscription_expiry', website writes 'subscription_end')
        final expiryTimestamp =
            (data?['subscription_expiry'] ?? data?['subscription_end'])
                as Timestamp?;
        _currentExpiry = expiryTimestamp?.toDate();

        // Read plan name
        _currentPlan = data?['subscription_plan'] as String?;

        // Cache the subscription status
        await _cacheSubscription();

        debugPrint(
          'Subscription fetched: $_currentStatus, plan: $_currentPlan (expires: $_currentExpiry)',
        );
      } else {
        _currentStatus = SubscriptionStatus.free;
        _currentExpiry = null;
        _currentPlan = null;
      }
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      // Try to use cached data
      await _loadCachedSubscription();
    }
  }

  /// Cache subscription status securely
  Future<void> _cacheSubscription() async {
    await _secureStorage.write(key: _cachedStatusKey, value: _currentStatus);
    if (_currentExpiry != null) {
      await _secureStorage.write(
        key: _cachedExpiryKey,
        value: _currentExpiry!.toIso8601String(),
      );
    }
    await _secureStorage.write(
      key: _cacheFreshnessKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  /// Load cached subscription status
  Future<void> _loadCachedSubscription() async {
    final cachedStatus = await _secureStorage.read(key: _cachedStatusKey);
    final cachedExpiry = await _secureStorage.read(key: _cachedExpiryKey);
    final cacheTime = await _secureStorage.read(key: _cacheFreshnessKey);

    if (cachedStatus != null) {
      // Check cache freshness
      if (cacheTime != null) {
        final cacheDate = DateTime.tryParse(cacheTime);
        if (cacheDate != null &&
            DateTime.now().difference(cacheDate) > _cacheValidity) {
          debugPrint('Subscription cache expired');
          // Cache is stale, but still use it for offline access
        }
      }

      _currentStatus = cachedStatus;
      if (cachedExpiry != null) {
        _currentExpiry = DateTime.tryParse(cachedExpiry);
      }

      debugPrint('Loaded cached subscription: $_currentStatus');
    }
  }

  /// Check if content is accessible based on subscription
  Future<bool> canAccessPremiumContent(String userId) async {
    // If we don't have cached data, fetch it
    if (_currentStatus == null) {
      await fetchSubscription(userId);
    }

    return hasActiveSubscription;
  }

  /// Check if downloaded content can be played offline
  /// Uses cached subscription status
  Future<bool> canPlayOfflineContent() async {
    if (_currentStatus == null) {
      await _loadCachedSubscription();
    }
    return hasActiveSubscription;
  }

  /// Clear cached subscription data (on logout)
  Future<void> clearCache() async {
    await _secureStorage.delete(key: _cachedStatusKey);
    await _secureStorage.delete(key: _cachedExpiryKey);
    await _secureStorage.delete(key: _cacheFreshnessKey);
    _currentStatus = null;
    _currentExpiry = null;
    debugPrint('Subscription cache cleared');
  }

  /// Stream subscription changes
  Stream<String> subscriptionStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return SubscriptionStatus.free;
      final data = doc.data();
      return data?['subscription_status'] as String? ?? SubscriptionStatus.free;
    });
  }

  /// Get days until subscription expires
  int? get daysUntilExpiry {
    if (_currentExpiry == null) return null;
    final diff = _currentExpiry!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays;
  }

  /// Check if subscription is expiring soon (within 7 days)
  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return days != null && days <= 7 && days > 0;
  }

  /// Get current subscription plan
  SubscriptionPlan? getCurrentPlan() {
    if (_currentPlan == null) return null;
    return SubscriptionPlan.fromName(_currentPlan);
  }

  /// Activate subscription after successful payment
  Future<void> activateSubscription({
    required String userId,
    required SubscriptionPlan plan,
    required String razorpayPaymentId,
    required String? razorpaySubscriptionId,
    required bool isYearly,
  }) async {
    try {
      final now = DateTime.now();
      final expiryDate = plan.tier == PlanTier.lifetime
          ? now.add(const Duration(days: 36500)) // 100 years
          : now.add(const Duration(days: 30));

      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'subscription_plan': plan.tier.name,
        'subscription_status': SubscriptionStatus.active,
        'subscription_expiry': Timestamp.fromDate(expiryDate),
        'razorpay_subscription_id': razorpaySubscriptionId,
        'subscription_activated_at': FieldValue.serverTimestamp(),
        'last_payment_id': razorpayPaymentId,
      });

      // Update local cache
      _currentStatus = SubscriptionStatus.active;
      _currentExpiry = expiryDate;
      _currentPlan = plan.tier.name;
      await _cacheSubscription();

      // Optionally create a subscription record in a separate collection
      await _firestore.collection('subscriptions').add({
        'user_id': userId,
        'plan_id': plan.tier.name,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_subscription_id': razorpaySubscriptionId,
        'amount': isYearly ? plan.priceYearly : plan.priceMonthly,
        'currency': 'INR',
        'billing_cycle': isYearly ? 'yearly' : 'monthly',
        'status': SubscriptionStatus.active,
        'created_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromDate(expiryDate),
      });

      debugPrint('Subscription activated: ${plan.name} until $expiryDate');
    } catch (e) {
      debugPrint('Error activating subscription: $e');
      rethrow;
    }
  }

  /// Cancel subscription
  Future<void> cancelSubscription(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);

      await userRef.update({
        'subscription_status': 'cancelled',
        'subscription_cancelled_at': FieldValue.serverTimestamp(),
      });

      _currentStatus = 'cancelled';
      await _cacheSubscription();

      debugPrint('Subscription cancelled for user: $userId');
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      rethrow;
    }
  }

  /// Get subscription plan name
  String? get currentPlanName => _currentPlan;

  List<SubscriptionPlan>? _cachedPlans;

  /// Fetch available subscription plans from Firestore
  Future<List<SubscriptionPlan>> fetchPlans() async {
    // Return cached plans if available and fresh
    if (_cachedPlans != null && _cachedPlans!.isNotEmpty) {
      return _cachedPlans!;
    }

    try {
      final snapshot = await _firestore.collection('plans').get();
      if (snapshot.docs.isNotEmpty) {
        final plans = snapshot.docs.map((doc) {
          final data = doc.data();
          // Ensure the tier enum matches the document ID or data
          // We might need to handle this carefully if the seed data structure differs
          return SubscriptionPlan.fromJson(data);
        }).toList();

        // Sort plans: Monthly first, then Lifetime
        plans.sort((a, b) => a.priceMonthly.compareTo(b.priceMonthly));

        _cachedPlans = plans;
        return plans;
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
    }

    // Fallback to hardcoded plans
    return SubscriptionPlan.paidPlans;
  }
}
