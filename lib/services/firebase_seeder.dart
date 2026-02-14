import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ransh_app/models/subscription_plan.dart';
import 'package:ransh_app/utils/logger.dart';

class FirebaseSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedAll() async {
    await seedLanguages();
    await seedPlans();
  }

  Future<void> seedLanguages() async {
    try {
      final languages = [
        {'code': 'en', 'name': 'English', 'nativeName': 'English'},
        {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
        {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी'},
      ];

      final batch = _firestore.batch();
      final configRef = _firestore.collection('config').doc('languages');

      // Set the supported languages array
      batch.set(configRef, {'supported': languages}, SetOptions(merge: true));

      await batch.commit();
      Logger.success('Languages seeded successfully');
    } catch (e) {
      Logger.error('Error seeding languages: $e');
      rethrow;
    }
  }

  Future<void> seedPlans() async {
    try {
      final plansRef = _firestore.collection('plans');
      final batch = _firestore.batch();

      // Monthly Plan
      final monthlyPlan = SubscriptionPlan.monthlyPlan;
      batch.set(plansRef.doc('monthly'), monthlyPlan.toJson());

      // Lifetime Plan
      final lifetimePlan = SubscriptionPlan.lifetimePlan;
      batch.set(plansRef.doc('lifetime'), lifetimePlan.toJson());

      await batch.commit();
      Logger.success('Subscription plans seeded successfully');
    } catch (e) {
      Logger.error('Error seeding plans: $e');
      rethrow;
    }
  }
}
