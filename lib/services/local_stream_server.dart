import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:ransh_app/services/encryption_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Local HTTP server for streaming encrypted content
/// This allows the video player to play encrypted files by serving
/// decrypted content on-the-fly through a localhost URL
class LocalStreamServer {
  static LocalStreamServer? _instance;

  final EncryptionService _encryptionService;
  HttpServer? _server;
  int? _port;

  // Cache for decrypted content to avoid re-decryption during seeking
  final Map<String, Uint8List> _decryptedCache = {};
  static const int _maxCacheSize = 3; // Max number of videos to cache

  LocalStreamServer._({required EncryptionService encryptionService})
    : _encryptionService = encryptionService;

  static LocalStreamServer getInstance({
    required EncryptionService encryptionService,
  }) {
    if (_instance == null) {
      _instance = LocalStreamServer._(encryptionService: encryptionService);
    } else {
      // Validate that the same encryption service is being used
      if (_instance!._encryptionService != encryptionService) {
        debugPrint(
          'Warning: Attempting to use different EncryptionService instance. '
          'Using existing instance.',
        );
      }
    }
    return _instance!;
  }

  /// Get the current server port (null if not started)
  int? get port => _port;

  /// Check if server is running
  bool get isRunning => _server != null;

  /// Get the base URL for streaming
  String? get baseUrl => _port != null ? 'http://127.0.0.1:$_port' : null;

  /// Start the local server
  Future<void> start() async {
    if (_server != null) {
      debugPrint('Local stream server already running on port $_port');
      return;
    }

    final router = Router();

    // Health check endpoint
    router.get('/health', (Request request) {
      return Response.ok('OK', headers: {'Content-Type': 'text/plain'});
    });

    // Stream endpoint for encrypted videos
    router.get('/stream/<filename>', _handleStreamRequest);

    // Get video info (content length) for the player
    router.head('/stream/<filename>', _handleHeadRequest);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    // Bind to localhost on a random available port
    _server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0, // 0 = random available port
    );

    _port = _server!.port;
    debugPrint('Local stream server started on http://127.0.0.1:$_port');
  }

  /// Stop the local server
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
    _decryptedCache.clear();
    debugPrint('Local stream server stopped');
  }

  /// Get streaming URL for a specific file
  String getStreamUrl(String fileName) {
    if (_port == null) {
      throw StateError('Server not started');
    }
    return 'http://127.0.0.1:$_port/stream/$fileName';
  }

  /// Handle HEAD request (returns content length for video player)
  Future<Response> _handleHeadRequest(Request request) async {
    final filename = request.params['filename'];
    if (filename == null) {
      return Response.notFound('Filename required');
    }

    try {
      final decryptedContent = await _getDecryptedContent(filename);

      return Response.ok(
        null,
        headers: {
          'Content-Type': _getContentType(filename),
          'Content-Length': '${decryptedContent.length}',
          'Accept-Ranges': 'bytes',
        },
      );
    } catch (e) {
      debugPrint('Error handling HEAD request: $e');
      return Response.notFound('File not found');
    }
  }

  /// Handle streaming request with Range header support
  Future<Response> _handleStreamRequest(Request request) async {
    final filename = request.params['filename'];
    if (filename == null) {
      return Response.notFound('Filename required');
    }

    try {
      final decryptedContent = await _getDecryptedContent(filename);
      final contentLength = decryptedContent.length;

      // Check for Range header (for seeking support)
      final rangeHeader = request.headers['range'];

      if (rangeHeader != null) {
        return _handleRangeRequest(rangeHeader, decryptedContent, filename);
      }

      // Full content response
      return Response.ok(
        Stream.value(decryptedContent),
        headers: {
          'Content-Type': _getContentType(filename),
          'Content-Length': '$contentLength',
          'Accept-Ranges': 'bytes',
        },
      );
    } catch (e) {
      debugPrint('Error streaming file: $e');
      return Response.notFound('File not found or decryption failed');
    }
  }

  /// Handle partial content request for seeking
  Response _handleRangeRequest(
    String rangeHeader,
    Uint8List content,
    String filename,
  ) {
    // Parse Range header: "bytes=0-1024" or "bytes=1024-"
    final matches = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);

    if (matches == null) {
      return Response(416, body: 'Invalid Range');
    }

    final start = int.parse(matches.group(1)!);
    final end = matches.group(2)?.isNotEmpty == true
        ? int.parse(matches.group(2)!)
        : content.length - 1;

    if (start >= content.length || start > end) {
      return Response(
        416,
        body: 'Range Not Satisfiable',
        headers: {'Content-Range': 'bytes */${content.length}'},
      );
    }

    final actualEnd = end.clamp(start, content.length - 1);
    final chunk = content.sublist(start, actualEnd + 1);

    return Response(
      206, // Partial Content
      body: Stream.value(chunk),
      headers: {
        'Content-Type': _getContentType(filename),
        'Content-Length': '${chunk.length}',
        'Content-Range': 'bytes $start-$actualEnd/${content.length}',
        'Accept-Ranges': 'bytes',
      },
    );
  }

  /// Get decrypted content with caching
  Future<Uint8List> _getDecryptedContent(String filename) async {
    // Check cache first
    if (_decryptedCache.containsKey(filename)) {
      debugPrint('Cache hit for: $filename');
      return _decryptedCache[filename]!;
    }

    // Get file path and decrypt
    final filePath = await _encryptionService.getEncryptedFilePath(filename);
    final decrypted = await _encryptionService.decryptFile(filePath);

    // Add to cache (evict oldest if needed)
    if (_decryptedCache.length >= _maxCacheSize) {
      final oldestKey = _decryptedCache.keys.first;
      _decryptedCache.remove(oldestKey);
      debugPrint('Evicted from cache: $oldestKey');
    }

    _decryptedCache[filename] = decrypted;
    debugPrint(
      'Cached decrypted content: $filename (${decrypted.length} bytes)',
    );

    return decrypted;
  }

  /// Clear cache for a specific file
  void clearCache(String filename) {
    _decryptedCache.remove(filename);
  }

  /// Clear all cached content
  void clearAllCache() {
    _decryptedCache.clear();
  }

  /// Get content type based on file extension
  String _getContentType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'm3u8':
        return 'application/vnd.apple.mpegurl';
      case 'ts':
        return 'video/mp2t';
      default:
        return 'application/octet-stream';
    }
  }

  /// CORS middleware for local requests
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Range, Content-Type',
    'Access-Control-Expose-Headers':
        'Content-Length, Content-Range, Accept-Ranges',
  };
}
