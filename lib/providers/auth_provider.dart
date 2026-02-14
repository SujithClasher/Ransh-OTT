import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ransh_app/models/user_session.dart';
import 'package:ransh_app/services/auth_service.dart';

import 'package:ransh_app/services/device_type_service.dart';
import 'package:ransh_app/services/notification_service.dart';
import 'package:ransh_app/services/download_service.dart';
import 'package:ransh_app/services/encryption_service.dart';
import 'package:ransh_app/services/mux_service.dart';
import 'package:ransh_app/services/local_stream_server.dart';
import 'package:ransh_app/services/session_sentinel.dart';
import 'package:ransh_app/services/subscription_service.dart';

// ============================================================================
// Service Providers
// ============================================================================

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Device type service provider
final deviceTypeServiceProvider = Provider<DeviceTypeService>((ref) {
  return DeviceTypeService.instance;
});

/// Notification service provider
final notificationServiceProvider = Provider((ref) => NotificationService());

/// Encryption service provider
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

/// Local stream server provider
final localStreamServerProvider = Provider<LocalStreamServer>((ref) {
  final encryptionService = ref.watch(encryptionServiceProvider);
  return LocalStreamServer.getInstance(encryptionService: encryptionService);
});

/// Session sentinel provider
final sessionSentinelProvider = Provider<SessionSentinel>((ref) {
  return SessionSentinel();
});

/// Subscription service provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Download service provider
final downloadServiceProvider = Provider<DownloadService>((ref) {
  final encryptionService = ref.watch(encryptionServiceProvider);
  final muxService = ref.watch(muxServiceProvider);
  return DownloadService(
    encryptionService: encryptionService,
    muxService: muxService,
  );
});

// ============================================================================
// State Providers
// ============================================================================

/// Auth state provider - streams authentication state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Is signed in provider
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Current user session provider - streams the full UserSession object from Firestore
final currentUserSessionProvider = StreamProvider<UserSession?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return UserSession.fromFirestore(doc);
      });
});

/// Device type state - holds the detected device type
final deviceTypeStateProvider = StateProvider<DeviceType?>((ref) => null);

/// Subscription status provider
final subscriptionStatusProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return subscriptionService.canAccessPremiumContent(user.uid);
});

/// Session active state
final sessionActiveProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// Action Providers
// ============================================================================

/// Sign in with Google
final signInProvider = FutureProvider.family<UserCredential?, BuildContext>((
  ref,
  context,
) async {
  final authService = ref.read(authServiceProvider);
  final sessionSentinel = ref.read(sessionSentinelProvider);
  final deviceTypeService = ref.read(deviceTypeServiceProvider);
  final subscriptionService = ref.read(subscriptionServiceProvider);

  // Sign in
  final credential = await authService.signInWithGoogle();

  if (credential?.user != null) {
    final userId = credential!.user!.uid;

    // Get device type
    final deviceType = await deviceTypeService.getDeviceType(context);
    ref.read(deviceTypeStateProvider.notifier).state = deviceType;

    // Initialize session
    await sessionSentinel.initializeSession(
      userId: userId,
      deviceType: deviceType,
    );
    ref.read(sessionActiveProvider.notifier).state = true;

    // Fetch subscription status
    await subscriptionService.fetchSubscription(userId);
  }

  return credential;
});

/// Sign out provider
final signOutProvider = FutureProvider<void>((ref) async {
  final authService = ref.read(authServiceProvider);
  final sessionSentinel = ref.read(sessionSentinelProvider);
  final encryptionService = ref.read(encryptionServiceProvider);
  final subscriptionService = ref.read(subscriptionServiceProvider);

  final userId = authService.currentUserId;

  if (userId != null) {
    await sessionSentinel.clearSession(userId);
  }

  await subscriptionService.clearCache();
  await authService.signOut();

  ref.read(sessionActiveProvider.notifier).state = false;
});

// ============================================================================
// Initialization Provider
// ============================================================================

/// App initialization provider - runs on app start
final appInitializationProvider = FutureProvider<bool>((ref) async {
  final encryptionService = ref.read(encryptionServiceProvider);
  final localServer = ref.read(localStreamServerProvider);

  // Initialize encryption service
  await encryptionService.initialize();

  // Start local streaming server
  await localServer.start();

  return true;
});
