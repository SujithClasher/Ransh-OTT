import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:ransh_app/models/ransh_content.dart';
import 'package:ransh_app/providers/auth_provider.dart';
import 'package:ransh_app/services/device_type_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:ransh_app/widgets/custom_player_overlay.dart';
import 'package:ransh_app/utils/mux_hls_parser.dart';
import 'package:ransh_app/services/mux_service.dart';

/// Video player screen for full-length content
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final RanshContent content;
  final bool isOffline;

  const VideoPlayerScreen({
    super.key,
    required this.content,
    this.isOffline = false,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  List<MuxQuality> _qualities = [];
  String _currentQualityLabel = 'Auto';

  @override
  void initState() {
    super.initState();
    _initializePlayer();

    // Lock to landscape for video playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  String? _streamUrl; // Promoted to member variable for casting

  @override
  void dispose() {
    _controller?.dispose();
    WakelockPlus.disable(); // Allow screen sleep

    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      await WakelockPlus.enable(); // Prevent screen sleep
      if (widget.isOffline) {
        // Get URL from local server for encrypted playback
        final localServer = ref.read(localStreamServerProvider);
        final fileName = '${widget.content.id}.mp4';
        _streamUrl = localServer.getStreamUrl(fileName);
      } else {
        // Direct HLS URL from Mux
        _streamUrl = widget.content.playbackUrl;

        // Fetch available qualities
        MuxHlsParser.getQualities(widget.content.muxPlaybackId).then((qs) {
          if (mounted) {
            setState(() {
              _qualities = qs;
            });
          }
        });
      }

      debugPrint('[RANSH PLAYER] Content ID: ${widget.content.id}');
      debugPrint('[RANSH PLAYER] Playback ID: ${widget.content.muxPlaybackId}');
      debugPrint('[RANSH PLAYER] Stream URL: $_streamUrl');
      debugPrint('[RANSH PLAYER] isOffline: ${widget.isOffline}');

      if (_streamUrl == null || _streamUrl!.isEmpty) {
        debugPrint('[RANSH PLAYER] ERROR: Stream URL is null or empty!');
        setState(() {
          _error =
              'Unable to load video - No playback URL available.\n'
              'Playback ID: ${widget.content.muxPlaybackId}';
          _isLoading = false;
        });
        return;
      }

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_streamUrl!),
        formatHint: widget.isOffline ? null : VideoFormat.hls,
        httpHeaders: {},
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      // Listen for player errors
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          debugPrint(
            '[RANSH PLAYER] ExoPlayer Error: ${_controller!.value.errorDescription}',
          );
          if (mounted && _error == null) {
            setState(() {
              _error = 'Playback error: ${_controller!.value.errorDescription}';
              _isLoading = false;
            });
          }
        }
      });

      debugPrint('[RANSH PLAYER] Initializing controller...');
      await _controller!.initialize();
      debugPrint(
        '[RANSH PLAYER] Controller initialized. Duration: ${_controller!.value.duration}',
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stack) {
      debugPrint('[RANSH PLAYER] FATAL Error: $e');
      debugPrint('[RANSH PLAYER] Stack: $stack');
      if (mounted) {
        setState(() {
          _error = 'Error loading video: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ref.watch(deviceTypeStateProvider);
    final isTV = deviceType == DeviceType.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody(isTV)),
    );
  }

  Widget _buildBody(bool isTV) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading ${widget.content.title}...',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_error != null || _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              '${_error ?? 'Unknown error'}\n${_controller?.value.errorDescription ?? ''}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _goBack, child: const Text('Go Back')),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_controller!),
            // Custom overlay
            CustomPlayerOverlay(
              controller: _controller!,
              title: widget.content.title,
              isTV: isTV,
              showDownload: !widget.isOffline && !isTV,
              muxPlaybackId: widget.content.muxPlaybackId,
              onBackPressed: _goBack,
              onDownload: !widget.isOffline
                  ? () => _startDownload(context, ref)
                  : null,
              onQualityChange: !widget.isOffline
                  ? () => _changePlaybackQuality(context)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDownload(BuildContext context, WidgetRef ref) async {
    // 1. Fetch available options from Mux
    List<Map<String, dynamic>> options = [];
    final muxService = ref.read(muxServiceProvider);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      options = await muxService.getDownloadOptions(widget.content.muxAssetId);
    } catch (e) {
      debugPrint('Failed to get options: $e');
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    // 2. Handle missing options (Optimization needed)
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking download availability...'),
          duration: Duration(seconds: 2),
        ),
      );

      try {
        // Trigger self-healing
        final initiated = await muxService.enableMp4Support(
          widget.content.muxAssetId,
        );
        if (!context.mounted) return;

        if (initiated) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: Theme.of(context).dialogBackgroundColor,
              title: const Text(
                'Optimizing Video',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'This video is being optimized for offline viewing. Please try downloading again in 5-10 minutes.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Downloads temporarily unavailable for this video.',
              ),
            ),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return;
    }

    // 3. Show dynamic options
    final quality = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Download Quality',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...options.map((opt) {
            return ListTile(
              leading: Icon(
                opt['height'] >= 720 ? Icons.hd : Icons.sd_storage,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                opt['label'],
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                opt['filesize'] != null
                    ? '${((int.tryParse(opt['filesize'].toString()) ?? 0) / 1024 / 1024).toStringAsFixed(1)} MB'
                    : 'Unknown size',
                style: const TextStyle(color: Colors.white54),
              ),
              onTap: () => Navigator.pop(context, opt['name']),
            );
          }).toList(),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (quality == null) return; // User cancelled

    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Starting download ($quality)...')),
      );

      final downloadService = ref.read(downloadServiceProvider);
      await downloadService.downloadVideo(
        content: widget.content,
        preferredQuality: quality,
        onProgress: (progress) {
          debugPrint('Downloading: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Downloaded ${widget.content.title}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changePlaybackQuality(BuildContext context) async {
    final deviceType = ref.read(deviceTypeStateProvider);
    final isTV = deviceType == DeviceType.tv;

    // Use fetched qualities or fallback to Auto if none found
    if (_qualities.isEmpty && !widget.isOffline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fetching qualities...')));
      final qs = await MuxHlsParser.getQualities(widget.content.muxPlaybackId);
      if (mounted) setState(() => _qualities = qs);
    }

    // Define Auto option
    final autoQuality = MuxQuality(
      label: 'Auto',
      height: 0,
      bandwidth: 0,
      url: 'auto',
    );

    MuxQuality? selectedQuality;
    final bool useDialog = isTV;

    if (useDialog) {
      selectedQuality = await showDialog<MuxQuality>(
        context: context,
        builder: (context) => SimpleDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          title: const Text(
            'Select Quality',
            style: TextStyle(color: Colors.white),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, autoQuality),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Auto (Recommended)',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            ..._qualities.map(
              (q) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, q),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        q.height >= 720 ? Icons.hd : Icons.sd,
                        color: q.height >= 720 ? Colors.blue : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${q.label} ${q.height >= 720 ? "(HD)" : ""}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      selectedQuality = await showModalBottomSheet<MuxQuality>(
        context: context,
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Quality',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(
                'Auto (Recommended)',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, autoQuality),
              trailing: _currentQualityLabel == 'Auto'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ..._qualities.map(
              (q) => ListTile(
                leading: Icon(
                  q.height >= 720 ? Icons.hd : Icons.sd,
                  color: q.height >= 720 ? Colors.blue : Colors.orange,
                ),
                title: Text(
                  '${q.label} ${q.height >= 720 ? "(HD)" : ""}',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, q),
                trailing: _currentQualityLabel == q.label
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    if (selectedQuality != null && mounted) {
      _switchSource(selectedQuality);
    }
  }

  Future<void> _switchSource(dynamic quality, {bool isRetry = false}) async {
    // 1. Get current position
    final position = _controller?.value.position ?? Duration.zero;
    final wasPlaying = _controller?.value.isPlaying ?? false;

    setState(() => _isLoading = true);

    // Dispose old controller
    await _controller?.dispose();
    _controller = null;

    try {
      // 2. Determine new URL
      String url;
      String label;

      if (quality is MuxQuality && quality.url != 'auto') {
        url = quality.url;
        label = quality.label;
      } else {
        // Assume 'auto'
        url = widget.content.playbackUrl; // HLS Master
        label = 'Auto';
      }

      // 3. Initialize new controller
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.seekTo(position);

      if (wasPlaying) {
        await controller.play();
      }

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
          _currentQualityLabel = label;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $label'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Quality switch error: $e');

      // Only retry with auto if this wasn't already a retry attempt
      if (quality is MuxQuality && quality.url != 'auto' && !isRetry) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quality not available, reverting to Auto...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Retry with auto quality
        _switchSource('auto', isRetry: true);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Failed to switch quality.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load video. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
