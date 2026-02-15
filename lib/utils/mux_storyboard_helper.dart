import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MuxStoryboardHelper {
  static const String _muxImageHost = 'https://image.mux.com';

  /// Fetches and parses the storyboard VTT for a given playback ID
  static Future<List<StoryboardFrame>> getStoryboard(String playbackId) async {
    final vttUrl = '$_muxImageHost/$playbackId/storyboard.vtt';
    try {
      final response = await http.get(Uri.parse(vttUrl));
      if (response.statusCode == 200) {
        final frames = _parseVtt(response.body, playbackId);
        debugPrint(
          'MuxStoryboardHelper: Parsed ${frames.length} frames from $vttUrl',
        );
        return frames;
      } else {
        debugPrint(
          'MuxStoryboardHelper: Failed to fetch VTT ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching storyboard: $e');
    }
    return [];
  }

  /// Loads image from network for custom painting
  static Future<ui.Image?> loadSpriteSheet(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final Completer<ui.Image> completer = Completer();
        ui.decodeImageFromList(bytes, (ui.Image img) {
          completer.complete(img);
        });
        debugPrint('MuxStoryboardHelper: Loaded sprite sheet from $imageUrl');
        return completer.future;
      } else {
        debugPrint(
          'MuxStoryboardHelper: Failed to load sprite sheet ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error loading sprite sheet: $e');
    }
    return null;
  }

  static List<StoryboardFrame> _parseVtt(String vttContent, String playbackId) {
    final lines = vttContent.split('\n');
    final frames = <StoryboardFrame>[];

    double? startTime;
    double? endTime;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.contains('-->')) {
        final parts = line.split('-->');
        startTime = _parseTime(parts[0].trim());
        endTime = _parseTime(parts[1].trim());
      } else if (line.contains('#xywh=')) {
        // Example: storyboard.png#xywh=0,0,214,121
        final parts = line.split('#xywh=');
        String imageUrl = parts[0];

        // Handle relative URLs
        if (!imageUrl.startsWith('http')) {
          imageUrl = '$_muxImageHost/$playbackId/$imageUrl';
        }

        final coords = parts[1].split(',');

        if (coords.length == 4 && startTime != null && endTime != null) {
          frames.add(
            StoryboardFrame(
              startTime: startTime,
              endTime: endTime,
              imageUrl: imageUrl,
              x: int.parse(coords[0]),
              y: int.parse(coords[1]),
              width: int.parse(coords[2]),
              height: int.parse(coords[3]),
            ),
          );
        }
      }
    }
    return frames;
  }

  static double _parseTime(String timeStr) {
    // Format: HH:MM:SS.mmm or MM:SS.mmm
    final parts = timeStr.split(':');
    double seconds = 0;

    if (parts.length == 3) {
      seconds += double.parse(parts[0]) * 3600;
      seconds += double.parse(parts[1]) * 60;
      seconds += double.parse(parts[2]);
    } else if (parts.length == 2) {
      seconds += double.parse(parts[0]) * 60;
      seconds += double.parse(parts[1]);
    }
    return seconds;
  }
}

class StoryboardFrame {
  final double startTime;
  final double endTime;
  final String imageUrl;
  final int x;
  final int y;
  final int width;
  final int height;

  StoryboardFrame({
    required this.startTime,
    required this.endTime,
    required this.imageUrl,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
