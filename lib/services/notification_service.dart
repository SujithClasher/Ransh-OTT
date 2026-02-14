import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Cloud Messaging (FCM)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Local notifications plugin (for displaying notifications when app is in foreground)
  // We need to add flutter_local_notifications dependency if we want foreground banners on Android
  // For now, we will just use FCM's default behavior (which only shows notification in background)
  // To keep it simple in this phase.

  String? _fcmToken;

  /// Initialize notifications
  Future<void> initialize() async {
    // Request permission (Required for iOS, and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get token
      _fcmToken = await _fcm.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('FCM Token Refreshed: $_fcmToken');

        // Update token in Firestore user profile
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
                  'fcm_token': newToken,
                  'fcm_token_updated_at': FieldValue.serverTimestamp(),
                });
            debugPrint('FCM token updated in Firestore');
          }
        } catch (e) {
          debugPrint('Error updating FCM token in Firestore: $e');
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );
          // If we want to show a dialog or snackbar, we can do it here.
        }
      });

      // Handle background message tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        // Navigator.pushNamed(context, '/message', arguments: message);
      });
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Subscribe to a topic (e.g. 'all', 'kids', 'parents')
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}
