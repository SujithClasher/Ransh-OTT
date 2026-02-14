import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ransh_content.g.dart';

/// Enum for content type
enum ContentType {
  @JsonValue('full')
  full,
  @JsonValue('shorts')
  shorts,
}

/// Enum for content access level
enum AccessLevel {
  @JsonValue('free')
  free,
  @JsonValue('premium')
  premium,
}

/// Represents content metadata stored in Ransh Firestore database
@JsonSerializable()
class RanshContent {
  /// Firestore document ID
  final String id;

  /// Mux Asset ID
  @JsonKey(name: 'mux_asset_id')
  final String muxAssetId;

  /// Mux Playback ID (for streaming)
  @JsonKey(name: 'mux_playback_id')
  final String muxPlaybackId;

  /// Content title
  final String title;

  /// Content description
  final String? description;

  /// Thumbnail URL (custom or Mux auto-generated)
  @JsonKey(name: 'thumbnail_url')
  final String? thumbnailUrl;

  /// Content type: 'full' or 'shorts'
  @JsonKey(name: 'content_type')
  final ContentType contentType;

  /// Access level: 'free' or 'premium'
  @JsonKey(name: 'access_level')
  final AccessLevel accessLevel;

  /// Content language code (e.g., 'en', 'hi', 'ta')
  final String language;

  /// Category/genre of the content
  final String? category;

  /// Tags for search and filtering
  final List<String>? tags;

  /// Duration in seconds (cached from Vimeo)
  final int? duration;

  /// Order for sorting in the feed
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  /// Whether content is published/visible
  @JsonKey(name: 'is_published')
  final bool isPublished;

  /// Creation timestamp
  @JsonKey(
    name: 'created_at',
    fromJson: _timestampFromJson,
    toJson: _timestampToJson,
  )
  final DateTime? createdAt;

  /// Last update timestamp
  @JsonKey(
    name: 'updated_at',
    fromJson: _timestampFromJson,
    toJson: _timestampToJson,
  )
  final DateTime? updatedAt;

  /// Age group recommendation (e.g., '2-4', '5-7', '8-10')
  @JsonKey(name: 'age_group')
  final String? ageGroup;

  /// View count for popularity sorting
  @JsonKey(name: 'view_count')
  final int viewCount;

  /// Computed thumbnail URL from Mux playback ID
  /// Falls back to stored thumbnailUrl if available
  String get secureThumbnailUrl {
    // Prefer stored custom URL if it exists
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl!;
    }

    // Generate Mux auto-thumbnail
    if (muxPlaybackId.isNotEmpty) {
      return 'https://image.mux.com/$muxPlaybackId/thumbnail.jpg?width=1280&height=720&fit_mode=smartcrop&time=1';
    }
    return '';
  }

  RanshContent({
    required this.id,
    required this.muxAssetId,
    required this.muxPlaybackId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.contentType = ContentType.full,
    this.accessLevel = AccessLevel.free,
    this.language = 'en',
    this.category,
    this.tags,
    this.duration,
    this.sortOrder = 0,
    this.isPublished = true,
    this.createdAt,
    this.updatedAt,
    this.ageGroup,
    this.viewCount = 0,
  });

  factory RanshContent.fromJson(Map<String, dynamic> json) =>
      _$RanshContentFromJson(json);
  Map<String, dynamic> toJson() => _$RanshContentToJson(this);

  // Removed: fromSupabase - now using Firestore only with Mux fields

  /// Create from Firestore document
  factory RanshContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RanshContent(
      id: doc.id,
      muxAssetId: data['mux_asset_id'] as String? ?? '',
      muxPlaybackId: data['mux_playback_id'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String?,
      thumbnailUrl: data['thumbnail_url'] as String?,
      contentType: _contentTypeFromString(data['content_type'] as String?),
      accessLevel: _accessLevelFromString(data['access_level'] as String?),
      language: data['language'] as String? ?? 'en',
      category: data['category'] as String?,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
      duration: data['duration'] as int?,
      sortOrder: data['sort_order'] as int? ?? 0,
      isPublished: data['is_published'] as bool? ?? true,
      createdAt: _timestampFromJson(data['created_at']),
      updatedAt: _timestampFromJson(data['updated_at']),
      ageGroup: data['age_group'] as String?,
      viewCount: data['view_count'] as int? ?? 0,
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'mux_asset_id': muxAssetId,
      'mux_playback_id': muxPlaybackId,
      'title': title,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'content_type': contentType.name,
      'access_level': accessLevel.name,
      'language': language,
      'category': category,
      'tags': tags,
      'duration': duration,
      'sort_order': sortOrder,
      'is_published': isPublished,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'age_group': ageGroup,
      'view_count': viewCount,
    };
  }

  /// Check if content is a short video
  bool get isShorts => contentType == ContentType.shorts;

  /// Check if content requires premium subscription
  bool get isPremium => accessLevel == AccessLevel.premium;

  /// Get HLS playback URL from Mux
  String get playbackUrl {
    if (muxPlaybackId.isEmpty) {
      return ''; // Return empty for videos without playback ID
    }
    return 'https://stream.mux.com/$muxPlaybackId.m3u8';
  }

  /// Get Mux download URL (MP4)
  String getDownloadUrl({String quality = 'medium'}) {
    if (muxPlaybackId.isEmpty) return '';
    // Quality options: low, medium, high
    return 'https://stream.mux.com/$muxPlaybackId/$quality.mp4';
  }

  /// Format duration for display
  String get formattedDuration {
    if (duration == null || duration == 0) return '--:--';
    final minutes = (duration! / 60).floor();
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create a copy with updated fields
  RanshContent copyWith({
    String? muxAssetId,
    String? muxPlaybackId,
    String? title,
    String? description,
    String? thumbnailUrl,
    ContentType? contentType,
    AccessLevel? accessLevel,
    String? language,
    String? category,
    List<String>? tags,
    int? duration,
    int? sortOrder,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ageGroup,
    int? viewCount,
  }) {
    return RanshContent(
      id: id,
      muxAssetId: muxAssetId ?? this.muxAssetId,
      muxPlaybackId: muxPlaybackId ?? this.muxPlaybackId,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      contentType: contentType ?? this.contentType,
      accessLevel: accessLevel ?? this.accessLevel,
      language: language ?? this.language,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      duration: duration ?? this.duration,
      sortOrder: sortOrder ?? this.sortOrder,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ageGroup: ageGroup ?? this.ageGroup,
      viewCount: viewCount ?? this.viewCount,
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

/// Helper to convert string to ContentType enum
ContentType _contentTypeFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'shorts':
      return ContentType.shorts;
    case 'full':
    default:
      return ContentType.full;
  }
}

/// Helper to convert string to AccessLevel enum
AccessLevel _accessLevelFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'premium':
      return AccessLevel.premium;
    case 'free':
    default:
      return AccessLevel.free;
  }
}
