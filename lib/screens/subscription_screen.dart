import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ransh_app/models/subscription_plan.dart';
import 'package:ransh_app/providers/auth_provider.dart';
import 'package:ransh_app/services/razorpay_service.dart';
import 'package:ransh_app/services/subscription_service.dart';
import 'package:ransh_app/widgets/subscription_card.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Netflix-style subscription selection screen
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late RazorpayService _razorpayService;
  late TabController _tabController;
  bool _isLoading = false;
  String _billingCycle = 'monthly'; // 'monthly' or 'yearly'
  bool _isLoadingPlans = true;
  String? _currentPlan; // Track user's current plan
  List<SubscriptionPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    final subscriptionService = ref.read(subscriptionServiceProvider);

    // Fetch plans first
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
          _plans = SubscriptionPlan.paidPlans; // Fallback
          _isLoadingPlans = false;
        });
      }
    }

    // Fetch user status
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await subscriptionService.fetchSubscription(user.uid);
      if (mounted) {
        setState(() {
          _currentPlan = subscriptionService.currentPlanName;
        });
      }
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onPlanSelected(SubscriptionPlan plan) async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
        setState(() => _isLoading = false);
      }
      return;
    }

    final isYearly = _billingCycle == 'yearly';

    try {
      await _razorpayService.openCheckout(
        plan: plan,
        userEmail: user.email ?? '',
        userName: user.displayName ?? '',
        isYearly: isYearly,
        onSuccess: (response) =>
            _handlePaymentSuccess(response, plan, isYearly),
        onFailure: _handlePaymentFailure,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePaymentSuccess(
    PaymentSuccessResponse response,
    SubscriptionPlan plan,
    bool isYearly,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Activate subscription
      final subscriptionService = ref.read(subscriptionServiceProvider);
      await subscriptionService.activateSubscription(
        userId: user.uid,
        plan: plan,
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySubscriptionId: response.orderId,
        isYearly: isYearly,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ${plan.name}! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Activation failed: $e')));
      }
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message}'),
          backgroundColor: Colors.red,
        ),
      );
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

          // Plans grid
          Expanded(
            child: _isLoadingPlans
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _plans.map((plan) {
                      // Check against tier name (stored in DB) vs current plan
                      final isCurrentPlan = _currentPlan == plan.tier.name;

                      // Identify if user has lifetime access
                      final hasLifetime =
                          _currentPlan ==
                          SubscriptionPlan.lifetimePlan.tier.name;

                      // If user has lifetime, disable monthly plan
                      final isDisabled =
                          hasLifetime && plan.tier == PlanTier.monthly;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Opacity(
                          opacity: isDisabled ? 0.5 : 1.0,
                          child: SubscriptionCard(
                            plan: plan,
                            // No billing cycle choice anymore
                            isYearly: false,
                            isCurrentPlan: isCurrentPlan,
                            onTap: (isCurrentPlan || isDisabled)
                                ? null // Disable tap for current plan or if disabled
                                : () => _onPlanSelected(plan),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          // Footer info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Cancel anytime. Secure payment via Razorpay.',
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
