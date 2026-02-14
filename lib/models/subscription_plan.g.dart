// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionPlan _$SubscriptionPlanFromJson(Map<String, dynamic> json) =>
    SubscriptionPlan(
      tier: $enumDecode(_$PlanTierEnumMap, json['tier']),
      name: json['name'] as String,
      description: json['description'] as String,
      priceMonthly: (json['price_monthly'] as num).toInt(),
      priceYearly: (json['price_yearly'] as num).toInt(),
      features: (json['features'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      maxDevices: (json['max_devices'] as num).toInt(),
      quality: json['quality'] as String,
      isPopular: json['is_popular'] as bool? ?? false,
    );

Map<String, dynamic> _$SubscriptionPlanToJson(SubscriptionPlan instance) =>
    <String, dynamic>{
      'tier': _$PlanTierEnumMap[instance.tier]!,
      'name': instance.name,
      'description': instance.description,
      'price_monthly': instance.priceMonthly,
      'price_yearly': instance.priceYearly,
      'features': instance.features,
      'max_devices': instance.maxDevices,
      'quality': instance.quality,
      'is_popular': instance.isPopular,
    };

const _$PlanTierEnumMap = {
  PlanTier.monthly: 'monthly',
  PlanTier.lifetime: 'lifetime',
};
