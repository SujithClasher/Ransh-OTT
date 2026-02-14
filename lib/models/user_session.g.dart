// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserSession _$UserSessionFromJson(Map<String, dynamic> json) => UserSession(
  uid: json['uid'] as String,
  mobileSessionId: json['mobile_session_id'] as String?,
  tvSessionId: json['tv_session_id'] as String?,
  lastActiveMobile: _timestampFromJson(json['last_active_mobile']),
  lastActiveTv: _timestampFromJson(json['last_active_tv']),
  subscriptionStatus: json['subscription_status'] as String?,
  subscriptionExpiry: _timestampFromJson(json['subscription_expiry']),
  subscriptionPlan: json['subscription_plan'] as String?,
  razorpaySubscriptionId: json['razorpay_subscription_id'] as String?,
  razorpayCustomerId: json['razorpay_customer_id'] as String?,
  displayName: json['display_name'] as String?,
  email: json['email'] as String?,
  photoUrl: json['photo_url'] as String?,
  isAdmin: json['is_admin'] as bool? ?? false,
  preferredLanguage: json['preferred_language'] as String?,
);

Map<String, dynamic> _$UserSessionToJson(UserSession instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'mobile_session_id': instance.mobileSessionId,
      'tv_session_id': instance.tvSessionId,
      'last_active_mobile': _timestampToJson(instance.lastActiveMobile),
      'last_active_tv': _timestampToJson(instance.lastActiveTv),
      'subscription_status': instance.subscriptionStatus,
      'subscription_expiry': _timestampToJson(instance.subscriptionExpiry),
      'subscription_plan': instance.subscriptionPlan,
      'razorpay_subscription_id': instance.razorpaySubscriptionId,
      'razorpay_customer_id': instance.razorpayCustomerId,
      'display_name': instance.displayName,
      'email': instance.email,
      'photo_url': instance.photoUrl,
      'is_admin': instance.isAdmin,
      'preferred_language': instance.preferredLanguage,
    };
