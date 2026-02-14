import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ransh_app/models/user_session.dart';
import 'package:ransh_app/services/device_type_service.dart';
import 'package:uuid/uuid.dart';

/// Callback invoked when session is terminated by another device
typedef SessionTerminatedCallback = void Function(String reason);

/// Session Sentinel - Implements "1 Mobile + 1 TV" concurrency enforcement
/// Uses Firestore to track active sessions and enforce "Last-In-Wins" preemption
class SessionSentinel {
  static const String _localSessionKey = 'ransh_local_session_id';
  static const String _sessionTypeKey = 'ransh_session_type';

  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _secureStorage;
  final DeviceTypeService _deviceTypeService;

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  String? _localSessionId;
  DeviceType? _currentDeviceType;
  SessionTerminatedCallback? _onSessionTerminated;
  bool _isActive = false;

  SessionSentinel({
    FirebaseFirestore? firestore,
    FlutterSecureStorage? secureStorage,
    DeviceTypeService? deviceTypeService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _deviceTypeService = deviceTypeService ?? DeviceTypeService.instance;

  /// Check if session is currently active
  bool get isActive => _isActive;

  /// Get the current local session ID
  String? get localSessionId => _localSessionId;

  /// Set callback for session termination
  set onSessionTerminated(SessionTerminatedCallback? callback) {
    _onSessionTerminated = callback;
  }

  /// Initialize session for a user
  /// This creates a new session ID and registers it in Firestore
  Future<void> initializeSession({
    required String userId,
    required DeviceType deviceType,
  }) async {
    _currentDeviceType = deviceType;

    // Generate new session ID
    _localSessionId = const Uuid().v4();

    // Store locally
    await _secureStorage.write(key: _localSessionKey, value: _localSessionId);
    await _secureStorage.write(key: _sessionTypeKey, value: deviceType.name);

    // Register in Firestore using transaction for atomic write
    await _registerSession(userId, deviceType);

    // Start watching for session changes
    _startSessionWatcher(userId, deviceType);

    _isActive = true;
    debugPrint('Session initialized: $_localSessionId (${deviceType.name})');
  }

  /// Register session in Firestore
  Future<void> _registerSession(String userId, DeviceType deviceType) async {
    final userRef = _firestore.collection('users').doc(userId);

    // Use transaction to ensure atomic update
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(userRef);

      final now = DateTime.now();
      final fieldName = _getSessionFieldName(deviceType);
      final timestampField = _getTimestampFieldName(deviceType);

      if (doc.exists) {
        // Update existing document
        transaction.update(userRef, {
          fieldName: _localSessionId,
          timestampField: Timestamp.fromDate(now),
        });
      } else {
        // Create new document
        transaction.set(userRef, {
          fieldName: _localSessionId,
          timestampField: Timestamp.fromDate(now),
        });
      }
    });

    debugPrint('Session registered in Firestore');
  }

  /// Start watching Firestore for session changes
  void _startSessionWatcher(String userId, DeviceType deviceType) {
    _sessionSubscription?.cancel();

    final userRef = _firestore.collection('users').doc(userId);

    _sessionSubscription = userRef.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        _checkSessionValidity(data, deviceType);
      },
      onError: (error) {
        debugPrint('Error watching session: $error');
      },
    );
  }

  /// Check if the current session is still valid
  void _checkSessionValidity(Map<String, dynamic> data, DeviceType deviceType) {
    final fieldName = _getSessionFieldName(deviceType);
    final remoteSessionId = data[fieldName] as String?;

    if (remoteSessionId != null &&
        remoteSessionId != _localSessionId &&
        _isActive) {
      // Another device has taken over this session slot
      debugPrint('Session preempted by another device');
      _terminateSession(
        'Another ${deviceType.name} device has signed in to your account.',
      );
    }
  }

  /// Terminate the current session
  void _terminateSession(String reason) {
    _isActive = false;
    _onSessionTerminated?.call(reason);
  }

  /// Get the Firestore field name for the session ID
  String _getSessionFieldName(DeviceType deviceType) {
    return deviceType == DeviceType.tv ? 'tv_session_id' : 'mobile_session_id';
  }

  /// Get the Firestore field name for the timestamp
  String _getTimestampFieldName(DeviceType deviceType) {
    return deviceType == DeviceType.tv
        ? 'last_active_tv'
        : 'last_active_mobile';
  }

  /// Update last active timestamp
  Future<void> updateActivity(String userId) async {
    if (!_isActive || _currentDeviceType == null) return;

    final userRef = _firestore.collection('users').doc(userId);
    final timestampField = _getTimestampFieldName(_currentDeviceType!);

    await userRef.update({timestampField: FieldValue.serverTimestamp()});
  }

  /// Clear session on logout
  Future<void> clearSession(String userId) async {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;

    if (_currentDeviceType != null) {
      final userRef = _firestore.collection('users').doc(userId);
      final fieldName = _getSessionFieldName(_currentDeviceType!);
      final timestampField = _getTimestampFieldName(_currentDeviceType!);

      try {
        await userRef.update({
          fieldName: FieldValue.delete(),
          timestampField: FieldValue.delete(),
        });
      } catch (e) {
        debugPrint('Error clearing session from Firestore: $e');
      }
    }

    await _secureStorage.delete(key: _localSessionKey);
    await _secureStorage.delete(key: _sessionTypeKey);

    _localSessionId = null;
    _currentDeviceType = null;
    _isActive = false;

    debugPrint('Session cleared');
  }

  /// Resume session from stored credentials
  Future<bool> resumeSession(String userId) async {
    final storedSessionId = await _secureStorage.read(key: _localSessionKey);
    final storedDeviceType = await _secureStorage.read(key: _sessionTypeKey);

    if (storedSessionId == null || storedDeviceType == null) {
      return false;
    }

    _localSessionId = storedSessionId;
    _currentDeviceType = DeviceType.values.firstWhere(
      (t) => t.name == storedDeviceType,
      orElse: () => DeviceType.mobile,
    );

    // Verify session is still valid in Firestore
    final userRef = _firestore.collection('users').doc(userId);
    final doc = await userRef.get();

    if (!doc.exists) {
      await clearSession(userId);
      return false;
    }

    final data = doc.data();
    final fieldName = _getSessionFieldName(_currentDeviceType!);
    final remoteSessionId = data?[fieldName] as String?;

    if (remoteSessionId != _localSessionId) {
      // Session was invalidated
      await clearSession(userId);
      return false;
    }

    // Session is valid, start watching
    _startSessionWatcher(userId, _currentDeviceType!);
    _isActive = true;

    debugPrint('Session resumed: $_localSessionId');
    return true;
  }

  /// Dispose of resources
  void dispose() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
  }
}
