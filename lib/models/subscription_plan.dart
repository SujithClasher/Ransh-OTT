import 'package:json_annotation/json_annotation.dart';

part 'subscription_plan.g.dart';

/// Subscription plan tiers
enum PlanTier {
  @JsonValue('monthly')
  monthly,
  @JsonValue('lifetime')
  lifetime,
}

/// Subscription plan model with pricing and features
@JsonSerializable()
class SubscriptionPlan {
  final PlanTier tier;
  final String name;
  final String description;

  /// Price in paise (₹199 = 19900 paise)
  @JsonKey(name: 'price_monthly')
  final int priceMonthly;

  /// Yearly price in paise (with discount)
  @JsonKey(name: 'price_yearly')
  final int priceYearly;

  final List<String> features;

  @JsonKey(name: 'max_devices')
  final int maxDevices;

  final String quality;

  @JsonKey(name: 'is_popular')
  final bool isPopular;

  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.description,
    required this.priceMonthly,
    required this.priceYearly,
    required this.features,
    required this.maxDevices,
    required this.quality,
    this.isPopular = false,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionPlanToJson(this);

  static const SubscriptionPlan monthlyPlan = SubscriptionPlan(
    tier: PlanTier.monthly,
    name: 'Monthly Premium',
    description: 'Full access for 1 month',
    priceMonthly: 39900, // ₹399
    priceYearly: 0, // Not applicable
    features: [
      'Unlock All Videos',
      'Ad-free Experience',
      'HD & 4K Quality',
      'Cancel Anytime',
    ],
    maxDevices: 4,
    quality: '4K Ultra HD',
  );

  static const SubscriptionPlan lifetimePlan = SubscriptionPlan(
    tier: PlanTier.lifetime,
    name: 'Lifetime Access',
    description: 'Pay once, enjoy forever',
    priceMonthly:
        599900, // ₹5999 (Using priceMonthly field to store base price for now to avoid breaking UI consumers immediately, or I just treat it as a one-time price)
    priceYearly: 0,
    features: [
      'Unlock Everything Forever',
      'No Monthly Fees',
      'VIP Support',
      'Early Access to New Content',
    ],
    maxDevices: 4,
    quality: '4K Ultra HD',
    isPopular: true,
  );

  /// Get formatted price
  String get formattedPrice {
    final price = priceMonthly;
    final rupees = price / 100;
    return '₹${rupees.toStringAsFixed(0)}';
  }

  /// Alias for backward compatibility if needed, else used for Monthly card
  String get formattedMonthlyPrice => formattedPrice;

  // Stubs for yearly to prevent errors in UI until updated
  String get formattedYearlyPrice => 'N/A';
  int get yearlySavings => 0;
  String get formattedYearlySavings => '0';

  /// Check if plan is premium tier or higher
  bool get isPremiumTier =>
      tier == PlanTier.monthly || tier == PlanTier.lifetime;

  /// Check if plan allows downloads
  bool get allowsDownloads => true;

  /// Get all available plans
  static List<SubscriptionPlan> get paidPlans => [monthlyPlan, lifetimePlan];

  /// Get plan by name
  static SubscriptionPlan? fromName(String? name) {
    if (name == null) return null;
    final lower = name.toLowerCase();
    if (lower == 'monthly' || lower.contains('monthly')) return monthlyPlan;
    if (lower == 'lifetime' || lower.contains('lifetime')) return lifetimePlan;
    return null;
  }
}
