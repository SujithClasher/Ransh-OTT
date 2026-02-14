// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ransh_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RanshContent _$RanshContentFromJson(Map<String, dynamic> json) => RanshContent(
  id: json['id'] as String,
  muxAssetId: json['mux_asset_id'] as String,
  muxPlaybackId: json['mux_playback_id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  thumbnailUrl: json['thumbnail_url'] as String?,
  contentType:
      $enumDecodeNullable(_$ContentTypeEnumMap, json['content_type']) ??
      ContentType.full,
  accessLevel:
      $enumDecodeNullable(_$AccessLevelEnumMap, json['access_level']) ??
      AccessLevel.free,
  language: json['language'] as String? ?? 'en',
  category: json['category'] as String?,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  duration: (json['duration'] as num?)?.toInt(),
  sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  isPublished: json['is_published'] as bool? ?? true,
  createdAt: _timestampFromJson(json['created_at']),
  updatedAt: _timestampFromJson(json['updated_at']),
  ageGroup: json['age_group'] as String?,
  viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RanshContentToJson(RanshContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'mux_asset_id': instance.muxAssetId,
      'mux_playback_id': instance.muxPlaybackId,
      'title': instance.title,
      'description': instance.description,
      'thumbnail_url': instance.thumbnailUrl,
      'content_type': _$ContentTypeEnumMap[instance.contentType]!,
      'access_level': _$AccessLevelEnumMap[instance.accessLevel]!,
      'language': instance.language,
      'category': instance.category,
      'tags': instance.tags,
      'duration': instance.duration,
      'sort_order': instance.sortOrder,
      'is_published': instance.isPublished,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
      'age_group': instance.ageGroup,
      'view_count': instance.viewCount,
    };

const _$ContentTypeEnumMap = {
  ContentType.full: 'full',
  ContentType.shorts: 'shorts',
};

const _$AccessLevelEnumMap = {
  AccessLevel.free: 'free',
  AccessLevel.premium: 'premium',
};
