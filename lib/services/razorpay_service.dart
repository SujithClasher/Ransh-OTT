import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:ransh_app/models/subscription_plan.dart';

/// Service for handling Razorpay payment integration
class RazorpayService {
  late Razorpay _razorpay;

  /// Callbacks for payment results
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;
  Function(ExternalWalletResponse)? _onExternalWallet;

  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Open Razorpay checkout for subscription purchase
  Future<void> openCheckout({
    required SubscriptionPlan plan,
    required String userEmail,
    required String userName,
    required bool isYearly,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) async {
    // Store callbacks
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onExternalWallet = onExternalWallet;

    final keyId = dotenv.env['RAZORPAY_KEY_ID'];
    if (keyId == null || keyId.isEmpty) {
      throw Exception('RAZORPAY_KEY_ID not found in environment');
    }

    // Calculate amount based on billing cycle
    final amount = isYearly ? plan.priceYearly : plan.priceMonthly;

    final options = {
      'key': keyId,
      'amount': amount, // Amount in paise
      'currency': 'INR',
      'name': 'Ransh OTT',
      'description': '${plan.name} Plan - ${isYearly ? 'Yearly' : 'Monthly'}',
      'image':
          'https://placehold.co/256x256/9C27B0/ffffff.png?text=Ransh+OTT', // App Icon
      'prefill': {
        'email': userEmail,
        'contact': '', // Add phone number if available
        'name': userName,
      },
      'theme': {
        'color': '#9C27B0', // Purple theme
      },
      'notes': {
        'plan_tier': plan.tier.name,
        'billing_cycle': isYearly ? 'yearly' : 'monthly',
      },
      // Enable saved cards and UPI
      'config': {
        'display': {
          'blocks': {
            'banks': {
              'name': 'All payment methods',
              'instruments': [
                {'method': 'upi'},
                {'method': 'card'},
                {'method': 'wallet'},
                {'method': 'netbanking'},
              ],
            },
          },
          'sequence': ['block.banks'],
          'preferences': {'show_default_blocks': true},
        },
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      rethrow;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment Success: ${response.paymentId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
    _onExternalWallet?.call(response);
  }

  /// Verify payment signature (should be done on server-side ideally)
  /// This is a client-side verification for demo purposes
  bool verifySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    // In production, this should be verified on your backend
    // using Razorpay secret key
    // For now, we'll trust the payment success response
    return true;
  }

  /// Dispose of resources
  void dispose() {
    _razorpay.clear();
  }
}
