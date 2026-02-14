import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ransh_app/utils/logger.dart';

final muxServiceProvider = Provider((ref) => MuxService());

/// Service for Mux Video Platform integration
class MuxService {
  static const String _baseUrl = 'https://api.mux.com';

  final String _tokenId;
  final String _tokenSecret;

  MuxService()
    : _tokenId = dotenv.env['MUX_TOKEN_ID'] ?? '',
      _tokenSecret = dotenv.env['MUX_TOKEN_SECRET'] ?? '' {
    if (_tokenId.isEmpty || _tokenSecret.isEmpty) {
      throw Exception('Mux credentials not found in environment');
    }
  }

  /// Get authorization header
  Map<String, String> get _authHeaders {
    final credentials = base64.encode(utf8.encode('$_tokenId:$_tokenSecret'));
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
    };
  }

  /// Create a new direct upload URL
  /// Returns: { upload_url, asset_id }
  Future<Map<String, dynamic>> createDirectUpload({
    Duration? maxDuration,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/video/v1/uploads'),
        headers: _authHeaders,
        body: jsonEncode({
          'new_asset_settings': {
            'playback_policy': ['public'],
            'mp4_support': 'capped-1080p', // Enable MP4 downloads
          },
          'cors_origin': '*',
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body)['data'];
        Logger.info('Mux direct upload created: ${data['id']}');
        return {'upload_url': data['url'], 'upload_id': data['id']};
      } else {
        throw Exception('Failed to create upload: ${response.body}');
      }
    } catch (e) {
      Logger.error('Error creating Mux upload: $e');
      rethrow;
    }
  }

  /// Upload video file to Mux using direct upload URL
  Future<String> uploadVideo({
    required String uploadUrl,
    File? file,
    Uint8List? fileBytes,
    required Function(double) onProgress,
  }) async {
    try {
      final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));

      if (file != null) {
        final fileLength = await file.length();
        final stream = file.openRead();

        int bytesUploaded = 0;
        final streamWithProgress = stream.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (data, sink) {
              bytesUploaded += data.length;
              onProgress(bytesUploaded / fileLength);
              sink.add(data);
            },
          ),
        );

        request.contentLength = fileLength;
        request.headers['Content-Type'] = 'video/mp4';
        streamWithProgress.listen(
          request.sink.add,
          onDone: request.sink.close,
          onError: (Object error, StackTrace stackTrace) {
            request.sink.addError(error, stackTrace);
          },
        );
      } else if (fileBytes != null) {
        request.contentLength = fileBytes.length;
        request.headers['Content-Type'] = 'video/mp4';
        request.sink.add(fileBytes);
        request.sink.close();
        onProgress(1.0);
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        Logger.info('Video uploaded successfully to Mux');
        return 'success';
      } else {
        final body = await response.stream.bytesToString();
        throw Exception('Upload failed: $body');
      }
    } catch (e) {
      Logger.error('Error uploading video to Mux: $e');
      rethrow;
    }
  }

  /// Get upload status
  Future<Map<String, dynamic>> getUploadStatus(String uploadId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/video/v1/uploads/$uploadId'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      } else {
        throw Exception('Failed to get upload status: ${response.body}');
      }
    } catch (e) {
      Logger.error('Error getting upload status: $e');
      rethrow;
    }
  }

  /// Get asset details
  Future<Map<String, dynamic>> getAsset(String assetId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/video/v1/assets/$assetId'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      } else {
        throw Exception('Failed to get asset: ${response.body}');
      }
    } catch (e) {
      Logger.error('Error getting Mux asset: $e');
      rethrow;
    }
  }

  /// Wait for upload to become an asset (polling)
  Future<String> waitForUploadToBecomeAsset(
    String uploadId, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException('Upload processing timeout');
      }

      final status = await getUploadStatus(uploadId);
      final uploadStatus = status['status'];
      Logger.info('Upload status: $uploadStatus');

      if (status['asset_id'] != null) {
        return status['asset_id'];
      } else if (uploadStatus == 'errored') {
        final error = status['error'];
        throw Exception(
          'Upload failed: ${error?['message'] ?? 'Unknown error'}',
        );
      }

      await Future.delayed(pollInterval);
    }
  }

  /// Wait for asset to be ready (polling)
  Future<Map<String, dynamic>> waitForAssetReady(
    String assetId, {
    Duration pollInterval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 15),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException('Asset processing timeout');
      }

      final asset = await getAsset(assetId);
      final status = asset['status'];

      Logger.info('Asset status: $status');

      if (status == 'ready') {
        return asset;
      } else if (status == 'errored') {
        final errors = asset['errors'] ?? [];
        throw Exception('Asset processing failed: $errors');
      }

      await Future.delayed(pollInterval);
    }
  }

  /// Get playback ID from asset
  String? getPlaybackId(Map<String, dynamic> asset) {
    final playbackIds = asset['playback_ids'] as List?;
    if (playbackIds != null && playbackIds.isNotEmpty) {
      return playbackIds[0]['id'];
    }
    return null;
  }

  /// Get HLS playback URL
  String getPlaybackUrl(String playbackId) {
    return 'https://stream.mux.com/$playbackId.m3u8';
  }

  /// Get thumbnail URL
  /// Mux auto-generates thumbnails at various timestamps
  String getThumbnailUrl(
    String playbackId, {
    int width = 1280,
    int height = 720,
    String time = '1', // Seconds into video
    String fitMode = 'smartcrop',
  }) {
    return 'https://image.mux.com/$playbackId/thumbnail.jpg?width=$width&height=$height&time=$time&fit_mode=$fitMode';
  }

  /// Get animated GIF thumbnail
  String getAnimatedThumbnailUrl(
    String playbackId, {
    int width = 640,
    int height = 360,
    int fps = 15,
  }) {
    return 'https://image.mux.com/$playbackId/animated.gif?width=$width&height=$height&fps=$fps';
  }

  /// Get MP4 download URL (if mp4_support is enabled)
  String getDownloadUrl(String playbackId, {String quality = 'medium'}) {
    // Quality options: low, medium, high
    return 'https://stream.mux.com/$playbackId/$quality.mp4';
  }

  /// Upload custom thumbnail/poster and return its URL
  Future<String> setThumbnail({
    required String assetId, // Kept for backward compatibility/metadata linking
    required File imageFile,
  }) async {
    try {
      // 1. Create direct upload for the image
      final uploadResponse = await http.post(
        Uri.parse('$_baseUrl/video/v1/uploads'),
        headers: _authHeaders,
        body: jsonEncode({'cors_origin': '*'}),
      );

      if (uploadResponse.statusCode != 201) {
        throw Exception('Failed to create thumbnail upload');
      }

      final uploadData = jsonDecode(uploadResponse.body)['data'];
      final uploadUrl = uploadData['url'];
      final uploadId = uploadData['id'];

      // 2. Upload the image
      final imageBytes = await imageFile.readAsBytes();
      final putResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': 'image/jpeg'},
        body: imageBytes,
      );

      if (putResponse.statusCode != 200) {
        throw Exception('Failed to upload thumbnail image');
      }

      Logger.info('Thumbnail image uploaded, waiting for processing...');

      // 3. Wait for upload to become an asset
      final imageAssetId = await waitForUploadToBecomeAsset(uploadId);

      // 4. Wait for asset to be ready
      final imageAsset = await waitForAssetReady(imageAssetId);
      final imagePlaybackId = getPlaybackId(imageAsset);

      if (imagePlaybackId == null) {
        throw Exception('Failed to get playback ID for thumbnail');
      }

      // 5. Link to video asset (optional, but good for tracking)
      // We run this in background so we don't block returning the URL
      http
          .patch(
            Uri.parse('$_baseUrl/video/v1/assets/$assetId'),
            headers: _authHeaders,
            body: jsonEncode({
              'passthrough': jsonEncode({'custom_thumbnail': imageAssetId}),
            }),
          )
          .then((_) => Logger.info('Linked thumbnail to video asset'))
          .catchError(
            (e) => Logger.warning('Failed to link thumbnail metadata: $e'),
          );

      // 6. Return the standard Mux image URL for the *image* asset
      // For image assets, we don't need 'time' parameter
      return 'https://image.mux.com/$imagePlaybackId/thumbnail.jpg?width=1080&fit_mode=preserve';
    } catch (e) {
      Logger.error('Error setting custom thumbnail: $e');
      rethrow;
    }
  }

  /// Delete asset
  Future<void> deleteAsset(String assetId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/video/v1/assets/$assetId'),
        headers: _authHeaders,
      );

      if (response.statusCode == 204) {
        Logger.info('Asset deleted: $assetId');
      } else {
        throw Exception('Failed to delete asset: ${response.body}');
      }
    } catch (e) {
      Logger.error('Error deleting Mux asset: $e');
      rethrow;
    }
  }

  /// Create asset from URL (alternative upload method)
  Future<Map<String, dynamic>> createAssetFromUrl({
    required String videoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/video/v1/assets'),
        headers: _authHeaders,
        body: jsonEncode({
          'input': videoUrl,
          'playback_policy': ['public'],
          'mp4_support': 'capped-1080p',
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body)['data'];
        Logger.info('Mux asset created from URL: ${data['id']}');
        return data;
      } else {
        throw Exception('Failed to create asset: ${response.body}');
      }
    } catch (e) {
      Logger.error('Error creating Mux asset from URL: $e');
      rethrow;
    }
  }

  /// Get available quality renditions for a playback ID
  Future<List<Map<String, dynamic>>> getAvailableQualities(
    String playbackId,
  ) async {
    // Mux automatically generates multiple renditions
    // Return standard quality options
    return [
      {'label': 'Auto', 'value': 'auto', 'resolution': null},
      {'label': '1080p', 'value': '1080p', 'resolution': 1080},
      {'label': '720p', 'value': '720p', 'resolution': 720},
      {'label': '480p', 'value': '480p', 'resolution': 480},
      {'label': '360p', 'value': '360p', 'resolution': 360},
    ];
  }

  /// Enable MP4 support for an existing asset
  /// Returns true if update was initiated, false if already enabled
  Future<bool> enableMp4Support(String assetId) async {
    try {
      final asset = await getAsset(assetId);
      final mp4Support = asset['mp4_support'] as String?;

      if (mp4Support == 'standard' || mp4Support == 'capped-1080p') {
        return false; // Already enabled
      }

      Logger.info('Enabling MP4 support for asset: $assetId');

      final response = await http.put(
        Uri.parse('$_baseUrl/video/v1/assets/$assetId/mp4_support'),
        headers: _authHeaders,
        body: jsonEncode({'mp4_support': 'capped-1080p'}),
      );

      if (response.statusCode == 200) {
        Logger.success('MP4 support enabled for $assetId');
        return true;
      } else {
        throw Exception('Failed to enable MP4 support: ${response.body}');
      }
    } catch (e) {
      Logger.error('Error enabling MP4 support: $e');
      rethrow;
    }
  }

  /// Get available download options (static renditions) for an asset
  Future<List<Map<String, dynamic>>> getDownloadOptions(String assetId) async {
    try {
      final asset = await getAsset(assetId);
      final staticRenditions = asset['static_renditions'];

      if (staticRenditions == null || staticRenditions['status'] != 'ready') {
        Logger.info('Static renditions not ready for asset: $assetId');
        return [];
      }

      final files = (staticRenditions['files'] as List?) ?? [];
      final options = <Map<String, dynamic>>[];

      for (final file in files) {
        if (file['ext'] == 'mp4') {
          final height = file['height'] as int?;
          final name = file['name'] as String;
          // 'low.mp4', 'medium.mp4', 'high.mp4'

          String label = 'Standard';
          if (name.contains('low'))
            label = 'Data Saver (Low)';
          else if (name.contains('medium'))
            label = 'Standard Quality';
          else if (name.contains('high'))
            label = 'High Quality (Best)';
          else if (height != null)
            label = '${height}p';

          options.add({
            'label': label,
            'name': name.replaceAll('.mp4', ''), // 'low', 'medium', 'high'
            'height': height,
            'filesize': int.tryParse(file['filesize']?.toString() ?? '0'),
          });
        }
      }

      // Sort by quality (height) descending
      options.sort(
        (a, b) =>
            (b['height'] as int? ?? 0).compareTo(a['height'] as int? ?? 0),
      );

      return options;
    } catch (e) {
      Logger.error('Error fetching download options: $e');
      return [];
    }
  }
}
