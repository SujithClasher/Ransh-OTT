import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Subscriptions tab for admin to view all subscription analytics
class SubscriptionsTab extends ConsumerWidget {
  const SubscriptionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscriptions')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium, size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text(
                  'No subscriptions yet',
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
              ],
            ),
          );
        }

        // Calculate analytics
        int totalSubscriptions = docs.length;
        int basicCount = 0;
        int standardCount = 0;
        int premiumCount = 0;
        int activeCount = 0;
        double totalRevenue = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final planId = data['plan_id'] as String?;
          final status = data['status'] as String?;
          final amount = data['amount'] as int? ?? 0;

          if (status == 'active') activeCount++;
          totalRevenue += amount / 100; // Convert paise to rupees

          switch (planId) {
            case 'basic':
              basicCount++;
              break;
            case 'standard':
              standardCount++;
              break;
            case 'premium':
              premiumCount++;
              break;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Analytics cards
            _buildAnalyticsSection(
              context: context,
              totalSubscriptions: totalSubscriptions,
              activeCount: activeCount,
              basicCount: basicCount,
              standardCount: standardCount,
              premiumCount: premiumCount,
              totalRevenue: totalRevenue,
            ),

            const SizedBox(height: 24),

            // Recent subscriptions list
            const Text(
              'Recent Subscriptions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...docs.take(10).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildSubscriptionCard(data);
            }),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsSection({
    required BuildContext context,
    required int totalSubscriptions,
    required int activeCount,
    required int basicCount,
    required int standardCount,
    required int premiumCount,
    required double totalRevenue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                totalSubscriptions.toString(),
                Icons.subscriptions,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active',
                activeCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Basic',
                basicCount.toString(),
                Icons.star,
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Standard',
                standardCount.toString(),
                Icons.star,
                const Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Premium',
                premiumCount.toString(),
                Icons.star,
                const Color(0xFFFFD700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Revenue',
          '₹${totalRevenue.toStringAsFixed(2)}',
          Icons.currency_rupee,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> data) {
    final planId = data['plan_id'] as String? ?? 'unknown';
    final billingCycle = data['billing_cycle'] as String? ?? 'monthly';
    final amount = data['amount'] as int? ?? 0;
    final status = data['status'] as String? ?? 'unknown';

    DateTime? createdAt;
    final rawCreatedAt = data['created_at'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPlanColor(planId),
          child: const Icon(Icons.workspace_premium, color: Colors.white),
        ),
        title: Text(
          '${planId.toUpperCase()} - ${billingCycle.toUpperCase()}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${(amount / 100).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (createdAt != null)
              Text(
                _formatDate(createdAt),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status == 'active' ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getPlanColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'basic':
        return const Color(0xFF2196F3);
      case 'standard':
        return const Color(0xFF9C27B0);
      case 'premium':
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
