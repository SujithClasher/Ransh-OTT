import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ransh_app/models/subscription_plan.dart';
import 'package:ransh_app/providers/auth_provider.dart';
import 'package:ransh_app/services/subscription_service.dart';
import 'package:ransh_app/widgets/subscription_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Netflix-style subscription selection screen
/// Opens external browser for payment (Play Store compliant — 0% commission)
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with WidgetsBindingObserver {
  bool _isLoadingPlans = true;
  String? _currentPlan;
  List<SubscriptionPlan> _plans = [];
  StreamSubscription? _subscriptionListener;
  bool _hasShownSuccess = false;

  // ⚠️ Replace with your actual hosted URL
  static const String _subscriptionWebUrl =
      'https://ransh-ott.web.app'; // Firebase Hosting URL

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
    _startListeningToSubscription();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscriptionListener?.cancel();
    super.dispose();
  }

  /// Called when app resumes from background (e.g., returning from browser)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-fetch subscription status when user returns to app
      _refreshSubscriptionStatus();
    }
  }

  bool _isFirstSnapshot = true;

  /// Listen to Firestore user doc for real-time subscription changes
  void _startListeningToSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscriptionListener = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final data = snapshot.data();
          final status = data?['subscription_status'] as String?;
          final plan = data?['subscription_plan'] as String?;

          // Handle initial state load without triggering dialog
          if (_isFirstSnapshot) {
            _isFirstSnapshot = false;
            // Always update UI state, but silenced dialog
            setState(() {
              _currentPlan = plan;
            });
            return;
          }

          // Only show success if we weren't already subscribed/processed
          // and the status CHANGED to active
          if (status == 'active' && plan != null) {
            if (!_hasShownSuccess && _currentPlan != plan) {
              _hasShownSuccess = true;
              _onSubscriptionActivated(plan);
            }
            // Always update UI state
            setState(() {
              _currentPlan = plan;
            });
          }
        });
  }

  /// Manually re-fetch subscription when returning from browser
  Future<void> _refreshSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final status = doc.data()?['subscription_status'] as String?;
    final plan = doc.data()?['subscription_plan'] as String?;

    if (status == 'active' && plan != null && mounted) {
      if (!_hasShownSuccess && _currentPlan != plan) {
        _hasShownSuccess = true;
        _onSubscriptionActivated(plan);
      }
      setState(() {
        _currentPlan = plan;
      });
    }
  }

  /// Show success and pop back to home
  void _onSubscriptionActivated(String planName) {
    // Update local state
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      subscriptionService.fetchSubscription(user.uid);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Subscription Activated! 🎉',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You now have $planName access. Enjoy all premium content!',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(this.context).pop(); // Pop back to home
            },
            child: const Text(
              'Start Watching',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initData() async {
    final subscriptionService = ref.read(subscriptionServiceProvider);

    // Fetch plans
    try {
      final fetchedPlans = await subscriptionService.fetchPlans();
      if (mounted) {
        setState(() {
          _plans = fetchedPlans;
          _isLoadingPlans = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
      if (mounted) {
        setState(() {
          _plans = SubscriptionPlan.paidPlans;
          _isLoadingPlans = false;
        });
      }
    }

    // Fetch user subscription status
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await subscriptionService.fetchSubscription(user.uid);
      if (mounted) {
        setState(() {
          _currentPlan = subscriptionService.currentPlanName;

          // If already active on load, mark as shown so we don't pop dialog
          if (_currentPlan != null && _currentPlan!.isNotEmpty) {
            _hasShownSuccess = true;
          }
        });
      }
    }
  }

  /// Open external browser for subscription payment
  /// This follows Netflix's model — payments happen on external website
  /// to avoid Play Store's 30% commission.
  Future<void> _openSubscriptionWebsite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
      }
      return;
    }

    // Build URL with user identification params
    final params = {
      'uid': user.uid,
      'email': user.email ?? '',
      'name': user.displayName ?? '',
      'phone': user.phoneNumber ?? '',
    };

    final uri = Uri.parse(_subscriptionWebUrl).replace(queryParameters: params);

    try {
      // Launch in external browser (NOT WebView) — Play Store compliant
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open browser')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Unlock Ransh Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Get unlimited access to thousands of cartoons, rhymes, and stories.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const SizedBox(height: 32),

          // Plans grid (informational — shows what's available)
          Expanded(
            child: _isLoadingPlans
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _plans.map((plan) {
                      final isCurrentPlan = _currentPlan == plan.tier.name;
                      final hasLifetime =
                          _currentPlan ==
                          SubscriptionPlan.lifetimePlan.tier.name;
                      final isDisabled =
                          hasLifetime && plan.tier == PlanTier.monthly;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Opacity(
                          opacity: isDisabled ? 0.5 : 1.0,
                          child: SubscriptionCard(
                            plan: plan,
                            isYearly: false,
                            isCurrentPlan: isCurrentPlan,
                            onTap: (isCurrentPlan || isDisabled)
                                ? null
                                : () => _openSubscriptionWebsite(),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          // Subscribe Button
          if (_currentPlan == null || _currentPlan!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openSubscriptionWebsite,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Subscribe via Website',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          // Footer info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Secure payment via Razorpay. Opens in your browser.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
