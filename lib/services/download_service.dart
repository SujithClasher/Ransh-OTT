import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ransh_app/models/ransh_content.dart';
import 'package:ransh_app/services/encryption_service.dart';
import 'package:ransh_app/services/mux_service.dart';
import 'package:ransh_app/utils/logger.dart'; // Import Logger
import 'package:shared_preferences/shared_preferences.dart';

/// Service for downloading and encrypting videos for offline playback
/// Service for downloading and encrypting videos for offline playback
class DownloadService {
  final Dio _dio;
  final EncryptionService _encryptionService;
  final MuxService? _muxService; // Optional dependency for self-healing

  // Track active downloads
  final Map<String, CancelToken> _activeDownloads = {};

  DownloadService({
    Dio? dio,
    required EncryptionService encryptionService,
    MuxService? muxService,
  }) : _dio = dio ?? Dio(),
       _encryptionService = encryptionService,
       _muxService = muxService;

  /// Download and encrypt a video
  /// Returns the path to the encrypted file
  Future<String> downloadVideo({
    required RanshContent content,
    required Function(double progress) onProgress,
    String? preferredQuality,
  }) async {
    final contentId = content.id;
    List<String> qualities = ['high', 'medium', 'low'];

    if (preferredQuality != null) {
      qualities.remove(preferredQuality);
      qualities.insert(0, preferredQuality);
    }

    // Check if already downloading
    if (_activeDownloads.containsKey(contentId)) {
      throw Exception('Download already in progress');
    }

    final cancelToken = CancelToken();
    _activeDownloads[contentId] = cancelToken;

    try {
      Response<List<int>>? response;
      String? successQuality;

      // Try each quality until one works
      for (final q in qualities) {
        try {
          final url = content.getDownloadUrl(quality: q);
          // Logger.info('Trying download quality: $q'); // Too noisy

          response = await _dio.get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
            cancelToken: cancelToken,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                onProgress(received / total);
              }
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            successQuality = q;
            break; // Success!
          }
        } catch (e) {
          debugPrint('Quality $q failed: $e');
        }
      }

      if (response == null || response.data == null) {
        // Self-Healing: Check if we can enable MP4 support
        Logger.info(
          'Download failed for all qualities. Checking self-healing metrics...',
        );
        Logger.info(
          'muxAssetId: ${content.muxAssetId}, hasMuxService: ${_muxService != null}',
        );

        if (_muxService != null && content.muxAssetId.isNotEmpty) {
          try {
            Logger.info(
              'Download failed. Attempting to enable MP4 support for ${content.muxAssetId}',
            );
            final initiated = await _muxService!.enableMp4Support(
              content.muxAssetId,
            );
            if (initiated) {
              throw Exception(
                'Optimizing video for download (MP4 generation started). Please try again in 5-10 minutes.',
              );
            } else {
              // Already enabled but still failing? Maybe checking the asset details to see if static_renditions exist?
              // For now, just throw the standard error
            }
          } catch (e) {
            Logger.error('Self-healing failed: $e');
            if (e.toString().contains('Optimizing video')) rethrow;
          }
        }

        throw Exception(
          'Download failed - Video not optimized for offline viewing yet.',
        );
      }

      // Download thumbnail if available
      if (content.thumbnailUrl != null) {
        try {
          final thumbResponse = await _dio.get<List<int>>(
            content.thumbnailUrl!,
            options: Options(responseType: ResponseType.bytes),
          );

          if (thumbResponse.statusCode == 200 && thumbResponse.data != null) {
            await _encryptionService.saveUnencryptedFile(
              Uint8List.fromList(thumbResponse.data!),
              '$contentId.jpg',
            );
          }
        } catch (e) {
          Logger.error('Failed to download thumbnail: $e');
        }
      }

      // Encrypt and save video
      final encryptedPath = await _encryptionService.encryptStream(
        Stream.value(response.data!),
        '$contentId.mp4',
      );

      // Save metadata
      await _saveMetadata(content);

      Logger.success('Download complete ($successQuality): $encryptedPath');
      return encryptedPath;
    } finally {
      _activeDownloads.remove(contentId);
    }
  }

  /// Save content metadata
  Future<void> _saveMetadata(RanshContent content) async {
    final prefs = await SharedPreferences.getInstance();
    final metadata = prefs.getString('offline_content') ?? '{}';
    final Map<String, dynamic> metadataMap = Map<String, dynamic>.from(
      jsonDecode(metadata),
    );

    // Create clean metadata map with encoded dates
    final data = <String, dynamic>{
      'id': content.id,
      'title': content.title,
      'description': content.description,
      'thumbnail_url': content.thumbnailUrl,
      'content_type': content.contentType.name,
      'duration': content.duration,
      'local_path': '${content.id}.mp4',
      'created_at': content.createdAt?.toIso8601String(),
      'downloaded_at': DateTime.now().toIso8601String(),
      'mux_playback_id': content.muxPlaybackId,
    };

    metadataMap[content.id] = data;
    await prefs.setString('offline_content', jsonEncode(metadataMap));
  }

  /// Remove metadata
  Future<void> _removeMetadata(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final metadata = prefs.getString('offline_content');
    if (metadata != null) {
      final Map<String, dynamic> metadataMap = Map<String, dynamic>.from(
        jsonDecode(metadata),
      );

      if (metadataMap.containsKey(contentId)) {
        metadataMap.remove(contentId);
        await prefs.setString('offline_content', jsonEncode(metadataMap));
      }
    }
  }

  /// Cancel an active download
  void cancelDownload(String contentId) {
    final cancelToken = _activeDownloads[contentId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Download cancelled by user');
      _activeDownloads.remove(contentId);
    }
  }

  /// Check if a video is downloaded
  Future<bool> isDownloaded(String contentId) async {
    return _encryptionService.isFileDownloaded('$contentId.mp4');
  }

  /// Delete a downloaded video
  Future<void> deleteDownload(String contentId) async {
    await _encryptionService.deleteEncryptedFile('$contentId.mp4');
    await _removeMetadata(contentId);
  }

  /// Get list of all downloaded videos with metadata
  Future<List<RanshContent>> getDownloadedContent() async {
    final prefs = await SharedPreferences.getInstance();
    final metadata = prefs.getString('offline_content');

    if (metadata == null) return [];

    final Map<String, dynamic> metadataMap = jsonDecode(metadata);
    final List<RanshContent> contentList = [];

    // Verify files actually exist
    final files = await _encryptionService.getDownloadedFiles();
    final fileIds = files.map((f) => f.replaceAll('.mp4', '')).toSet();

    for (final key in metadataMap.keys) {
      if (fileIds.contains(key)) {
        try {
          final data = metadataMap[key] as Map<String, dynamic>;

          // We can try using fromFirestore if the structure matches
          // But we need a DocumentSnapshot... cumbersome.
          // Let's manually parse like before, adapted for Supabase fields if needed.

          final contentTypeStr = data['content_type'] as String?;
          final accessLevelStr = data['access_level'] as String?;

          contentList.add(
            RanshContent(
              id: key,
              muxAssetId: data['mux_asset_id'] ?? '',
              muxPlaybackId: data['mux_playback_id'] ?? '',
              title: data['title'] ?? 'Unknown',
              description: data['description'] ?? '',
              thumbnailUrl: data['thumbnail_url'],
              category: data['category'] ?? 'other',
              accessLevel: accessLevelStr == 'premium'
                  ? AccessLevel.premium
                  : AccessLevel.free,
              duration: data['duration'] ?? 0,
              tags: (data['tags'] as List?)?.cast<String>() ?? [],
              isPublished: true,
              createdAt:
                  DateTime.now(), // We don't save created_at typically in offline metadata
              language: data['language'] ?? 'en',
              contentType: contentTypeStr == 'shorts'
                  ? ContentType.shorts
                  : ContentType.full,
              sortOrder: 0,
            ),
          );
        } catch (e) {
          debugPrint('Error parsing metadata for $key: $e');
        }
      }
    }

    return contentList;
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    await _encryptionService.clearAllDownloads();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_content');
  }

  /// Check if a download is in progress
  bool isDownloading(String contentId) {
    return _activeDownloads.containsKey(contentId);
  }
}
