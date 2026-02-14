import 'package:http/http.dart' as http;

class MuxHlsParser {
  /// Fetches available video qualities (resolutions) from the Mux HLS master playlist.
  /// Returns a list of [MuxQuality] objects sorted by height (descending).
  static Future<List<MuxQuality>> getQualities(String playbackId) async {
    final url = 'https://stream.mux.com/$playbackId.m3u8';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return _parseMasterPlaylist(response.body, url);
      }
    } catch (e) {
      print('Error fetching HLS master playlist: $e');
    }
    return [];
  }

  static List<MuxQuality> _parseMasterPlaylist(
    String content,
    String masterUrl,
  ) {
    final lines = content.split('\n');
    final qualities = <MuxQuality>[];

    int? bandwidth;
    int? height;
    String? label;

    for (var i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        // Parse attributes
        // Example: #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=2962000,ola="...","RESOLUTION=1920x1080",...

        // Extract Bandwidth
        final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        if (bwMatch != null) bandwidth = int.parse(bwMatch.group(1)!);

        // Extract Resolution
        final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
        if (resMatch != null) {
          // int width = int.parse(resMatch.group(1)!);
          height = int.parse(resMatch.group(2)!);
        }

        // Determine label
        if (height != null) {
          if (height >= 1080)
            label = '1080p';
          else if (height >= 720)
            label = '720p';
          else if (height >= 480)
            label = '480p';
          else if (height >= 360)
            label = '360p';
          else
            label = '${height}p';
        }
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        // This is the URL line for the variant
        if (height != null && label != null) {
          String variantUrl = line;

          // Handle relative URLs
          if (!variantUrl.startsWith('http')) {
            final baseUrl = masterUrl.substring(
              0,
              masterUrl.lastIndexOf('/') + 1,
            );
            variantUrl = baseUrl + variantUrl;
          }

          qualities.add(
            MuxQuality(
              label: label,
              height: height,
              bandwidth: bandwidth ?? 0,
              url: variantUrl,
            ),
          );
        }

        // Reset for next entry
        bandwidth = null;
        height = null;
        label = null;
      }
    }

    // Sort by height descending (best quality first)
    qualities.sort((a, b) => b.height.compareTo(a.height));

    // Remove duplicates (sometimes same resolution has different bitrates, keep highest bitrate?)
    // Basic de-dupe by label
    final unique = <String, MuxQuality>{};
    for (var q in qualities) {
      if (!unique.containsKey(q.label)) {
        unique[q.label] = q;
      }
    }

    return unique.values.toList()..sort((a, b) => b.height.compareTo(a.height));
  }
}

class MuxQuality {
  final String label;
  final int height;
  final int bandwidth;
  final String url; // Absolute URL to the variant m3u8

  MuxQuality({
    required this.label,
    required this.height,
    required this.bandwidth,
    required this.url,
  });

  @override
  String toString() => '$label ($height p)';
}
