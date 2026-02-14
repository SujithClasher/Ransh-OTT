import 'package:flutter/material.dart';
import 'package:ransh_app/models/subscription_plan.dart';

/// Premium subscription card widget with glassmorphism
class SubscriptionCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isYearly;
  final bool isCurrentPlan;
  final VoidCallback? onTap;

  const SubscriptionCard({
    super.key,
    required this.plan,
    required this.isYearly,
    this.isCurrentPlan = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = plan.formattedPrice;
    final period = plan.priceMonthly > 100000
        ? 'once'
        : 'month'; // Hack for Lifetime vs Monthly detection

    return GestureDetector(
      onTap: isCurrentPlan ? null : onTap,
      child: Opacity(
        opacity: isCurrentPlan ? 0.7 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: _getGradient(context),
            borderRadius: BorderRadius.circular(20),
            border: isCurrentPlan
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: _getAccentColor(context).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Current Plan badge
              if (isCurrentPlan)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'CURRENT PLAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Popular badge
              if (plan.isPopular && !isCurrentPlan)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                    child: const Text(
                      '⭐ MOST POPULAR',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan name
                    Text(
                      plan.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      plan.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '/$period',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Features
                    ...plan.features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Subscribe button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCurrentPlan
                              ? Colors.grey
                              : Colors.white,
                          foregroundColor: isCurrentPlan
                              ? Colors.white70
                              : _getAccentColor(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isCurrentPlan) ...[
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              isCurrentPlan
                                  ? 'You own this plan'
                                  : 'Subscribe to ${plan.name}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _getGradient(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (plan.tier) {
      case PlanTier.monthly:
        return LinearGradient(
          colors: [colors.primary, colors.secondary], // Saffron to Amber Accent
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PlanTier.lifetime:
        return LinearGradient(
          colors: [
            colors.secondary,
            const Color(0xFFFFF8E1),
          ], // Amber Accent to Light Gold/Cream
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF9E9E9E), Color(0xFF757575)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getAccentColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (plan.tier) {
      case PlanTier.monthly:
        return colors.primary;
      case PlanTier.lifetime:
        return colors.secondary;
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}
