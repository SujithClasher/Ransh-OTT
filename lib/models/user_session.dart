import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_session.g.dart';

/// Represents the session state stored in Firestore for concurrency control
@JsonSerializable()
class UserSession {
  /// The user's Firebase UID
  final String uid;

  /// Session ID for the active mobile device (UUID)
  @JsonKey(name: 'mobile_session_id')
  final String? mobileSessionId;

  /// Session ID for the active TV device (UUID)
  @JsonKey(name: 'tv_session_id')
  final String? tvSessionId;

  /// Last activity timestamp for mobile device
  @JsonKey(
    name: 'last_active_mobile',
    fromJson: _timestampFromJson,
    toJson: _timestampToJson,
  )
  final DateTime? lastActiveMobile;

  /// Last activity timestamp for TV device
  @JsonKey(
    name: 'last_active_tv',
    fromJson: _timestampFromJson,
    toJson: _timestampToJson,
  )
  final DateTime? lastActiveTv;

  /// Subscription status: 'active', 'expired', 'free'
  @JsonKey(name: 'subscription_status')
  final String? subscriptionStatus;

  /// Subscription expiry date
  @JsonKey(
    name: 'subscription_expiry',
    fromJson: _timestampFromJson,
    toJson: _timestampToJson,
  )
  final DateTime? subscriptionExpiry;

  /// Current subscription plan tier
  @JsonKey(name: 'subscription_plan')
  final String? subscriptionPlan;

  /// Razorpay subscription ID
  @JsonKey(name: 'razorpay_subscription_id')
  final String? razorpaySubscriptionId;

  /// Razorpay customer ID
  @JsonKey(name: 'razorpay_customer_id')
  final String? razorpayCustomerId;

  /// User's display name
  @JsonKey(name: 'display_name')
  final String? displayName;

  /// User's email
  final String? email;

  /// User's photo URL
  @JsonKey(name: 'photo_url')
  final String? photoUrl;

  /// Whether user is an admin
  @JsonKey(name: 'is_admin')
  final bool isAdmin;

  /// Preferred language code
  @JsonKey(name: 'preferred_language')
  final String? preferredLanguage;

  UserSession({
    required this.uid,
    this.mobileSessionId,
    this.tvSessionId,
    this.lastActiveMobile,
    this.lastActiveTv,
    this.subscriptionStatus,
    this.subscriptionExpiry,
    this.subscriptionPlan,
    this.razorpaySubscriptionId,
    this.razorpayCustomerId,
    this.displayName,
    this.email,
    this.photoUrl,
    this.isAdmin = false,
    this.preferredLanguage,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) =>
      _$UserSessionFromJson(json);
  Map<String, dynamic> toJson() => _$UserSessionToJson(this);

  /// Create from Firestore document
  factory UserSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserSession(
      uid: doc.id,
      mobileSessionId: data['mobile_session_id'] as String?,
      tvSessionId: data['tv_session_id'] as String?,
      lastActiveMobile: _timestampFromJson(data['last_active_mobile']),
      lastActiveTv: _timestampFromJson(data['last_active_tv']),
      subscriptionStatus: data['subscription_status'] as String?,
      subscriptionExpiry: _timestampFromJson(data['subscription_expiry']),
      subscriptionPlan: data['subscription_plan'] as String?,
      razorpaySubscriptionId: data['razorpay_subscription_id'] as String?,
      razorpayCustomerId: data['razorpay_customer_id'] as String?,
      displayName: data['display_name'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photo_url'] as String?,
      isAdmin: data['is_admin'] as bool? ?? false,
      preferredLanguage: data['preferred_language'] as String?,
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'mobile_session_id': mobileSessionId,
      'tv_session_id': tvSessionId,
      'last_active_mobile': lastActiveMobile != null
          ? Timestamp.fromDate(lastActiveMobile!)
          : null,
      'last_active_tv': lastActiveTv != null
          ? Timestamp.fromDate(lastActiveTv!)
          : null,
      'subscription_status': subscriptionStatus,
      'subscription_expiry': subscriptionExpiry != null
          ? Timestamp.fromDate(subscriptionExpiry!)
          : null,
      'subscription_plan': subscriptionPlan,
      'razorpay_subscription_id': razorpaySubscriptionId,
      'razorpay_customer_id': razorpayCustomerId,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'is_admin': isAdmin,
      'preferred_language': preferredLanguage,
    };
  }

  /// Check if subscription is active
  bool get hasActiveSubscription {
    if (subscriptionStatus != 'active') return false;
    if (subscriptionExpiry == null) return true;
    return subscriptionExpiry!.isAfter(DateTime.now());
  }

  /// Check if user has premium tier subscription
  bool get isPremium {
    if (!hasActiveSubscription) return false;
    return subscriptionPlan == 'standard' ||
        subscriptionPlan == 'premium' ||
        subscriptionPlan == 'basic';
  }

  /// Create a copy with updated fields
  UserSession copyWith({
    String? mobileSessionId,
    String? tvSessionId,
    DateTime? lastActiveMobile,
    DateTime? lastActiveTv,
    String? subscriptionStatus,
    DateTime? subscriptionExpiry,
    String? subscriptionPlan,
    String? razorpaySubscriptionId,
    String? razorpayCustomerId,
    String? displayName,
    String? email,
    String? photoUrl,
    bool? isAdmin,
    String? preferredLanguage,
  }) {
    return UserSession(
      uid: uid,
      mobileSessionId: mobileSessionId ?? this.mobileSessionId,
      tvSessionId: tvSessionId ?? this.tvSessionId,
      lastActiveMobile: lastActiveMobile ?? this.lastActiveMobile,
      lastActiveTv: lastActiveTv ?? this.lastActiveTv,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      razorpaySubscriptionId:
          razorpaySubscriptionId ?? this.razorpaySubscriptionId,
      razorpayCustomerId: razorpayCustomerId ?? this.razorpayCustomerId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isAdmin: isAdmin ?? this.isAdmin,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}

/// Helper function to convert Firestore Timestamp to DateTime
DateTime? _timestampFromJson(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Helper function to convert DateTime to JSON-compatible format
dynamic _timestampToJson(DateTime? dateTime) {
  return dateTime?.toIso8601String();
}
