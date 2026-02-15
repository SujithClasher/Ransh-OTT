import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:ransh_app/models/ransh_content.dart';
import 'package:ransh_app/widgets/ransh_image.dart';

/// Shorts player with TikTok-style vertical scrolling
/// Handles pillarboxing for TV with blurred background
class ShortsPlayer extends StatefulWidget {
  final List<RanshContent> shorts;
  final int initialIndex;
  final bool isTV;
  final VoidCallback? onBack;

  const ShortsPlayer({
    super.key,
    required this.shorts,
    this.initialIndex = 0,
    this.isTV = false,
    this.onBack,
  });

  @override
  State<ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends State<ShortsPlayer> {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = {};
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _preloadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Preload current video and adjacent ones
  Future<void> _preloadVideos() async {
    // Load current, previous, and next
    final indices = [
      _currentIndex,
      if (_currentIndex > 0) _currentIndex - 1,
      if (_currentIndex < widget.shorts.length - 1) _currentIndex + 1,
    ];

    for (final index in indices) {
      await _loadVideo(index);
    }

    // Play current video
    _controllers[_currentIndex]?.play();
    setState(() => _isLoading = false);
  }

  /// Load video controller for an index
  Future<void> _loadVideo(int index) async {
    if (_controllers.containsKey(index)) return;
    if (index < 0 || index >= widget.shorts.length) return;

    final content = widget.shorts[index];

    // Use direct Mux HLS URL
    final streamUrl = content.playbackUrl;

    if (streamUrl.isEmpty) {
      debugPrint('No playback URL for shorts: ${content.title}');
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(streamUrl),
      httpHeaders: {},
    );

    try {
      await controller.initialize();
      controller.setLooping(true);

      if (mounted) {
        setState(() {
          _controllers[index] = controller;
        });

        // If the user has scrolled to this video while it was loading, play it now
        if (index == _currentIndex) {
          controller.play();
        }
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing video $index: $e');
    }
  }

  /// Unload videos that are no longer needed
  void _unloadDistantVideos() {
    final keysToRemove = <int>[];

    for (final key in _controllers.keys) {
      if ((key - _currentIndex).abs() > 1) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
  }

  void _onPageChanged(int index) {
    // Pause previous video
    _controllers[_currentIndex]?.pause();

    setState(() => _currentIndex = index);

    // Play new video
    _controllers[index]?.play();

    // Preload adjacent videos
    _loadVideo(index - 1);
    _loadVideo(index + 1);

    // Unload distant videos
    _unloadDistantVideos();
  }

  void _nextVideo() {
    if (_currentIndex < widget.shorts.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousVideo() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // TV D-pad navigation
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _previousVideo();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _nextVideo();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      // Toggle play/pause
      final controller = _controllers[_currentIndex];
      if (controller != null) {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      widget.onBack?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.isTV,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: _onPageChanged,
                itemCount: widget.shorts.length,
                itemBuilder: (context, index) {
                  return _buildShortItem(index);
                },
              ),
      ),
    );
  }

  Widget _buildShortItem(int index) {
    final content = widget.shorts[index];
    final controller = _controllers[index];

    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(content.title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    // For TV, show pillarboxed video with blurred background
    if (widget.isTV) {
      return _buildPillarboxedVideo(controller, content);
    }

    // For mobile/tablet, show full-screen vertical video
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          // Dark gradient at bottom for text readability
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),
          _buildOverlay(content),

          // Center Play/Pause Icon
          if (!controller.value.isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build pillarboxed video for TV (16:9 screen, 9:16 video)
  Widget _buildPillarboxedVideo(
    VideoPlayerController controller,
    RanshContent content,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred background (scaled to cover)
        if (content.secureThumbnailUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Transform.scale(
              scale: 1.2,
              child: RanshImage(
                imageUrl: content.secureThumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: Container(color: Colors.black),
              ),
            ),
          )
        else
          // Fallback: Use video as background (performance heavy)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Transform.scale(scale: 2, child: VideoPlayer(controller)),
          ),

        // Dark overlay for readability
        Container(color: Colors.black.withValues(alpha: 0.3)),

        // Centered video with aspect ratio
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),

        // Content overlay
        _buildOverlay(content),
      ],
    );
  }

  Widget _buildOverlay(RanshContent content) {
    return Positioned(
      left: 16,
      right: 80,
      bottom: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (content.description != null) ...[
            const SizedBox(height: 8),
            Text(
              content.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                shadows: const [Shadow(blurRadius: 4)],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
