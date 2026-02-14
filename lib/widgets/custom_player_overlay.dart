import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:ransh_app/utils/mux_storyboard_helper.dart';

/// Custom video player overlay with kids-friendly controls
/// Supports both touch (mobile/tablet) and D-pad (TV) navigation
class CustomPlayerOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onBackPressed;
  final VoidCallback? onDownload;
  final VoidCallback? onQualityChange;
  final String? title;
  final bool isTV;
  final bool showDownload;
  final String? muxPlaybackId; // Added for storyboard

  const CustomPlayerOverlay({
    super.key,
    required this.controller,
    this.onBackPressed,
    this.onDownload,
    this.onQualityChange,
    this.title,
    this.isTV = false,
    this.showDownload = false,
    this.muxPlaybackId,
  });

  @override
  State<CustomPlayerOverlay> createState() => _CustomPlayerOverlayState();
}

class _CustomPlayerOverlayState extends State<CustomPlayerOverlay>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Storyboard state
  List<StoryboardFrame> _storyboardFrames = [];
  ui.Image? _spriteSheet;
  Duration? _scrubbingTime;
  double? _scrubbingOffset;
  bool _isScrubbing = false;

  // Focus nodes for TV navigation
  final FocusNode _playPauseFocus = FocusNode();
  final FocusNode _seekBackFocus = FocusNode();
  final FocusNode _seekForwardFocus = FocusNode();
  final FocusNode _lockFocus = FocusNode();
  final FocusNode _backButtonFocus = FocusNode();
  final FocusNode _downloadButtonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _startHideTimer();

    widget.controller.addListener(_onControllerUpdate);

    // Load storyboard if playback ID is present
    if (widget.muxPlaybackId != null) {
      _loadStoryboard();
    }
  }

  Future<void> _loadStoryboard() async {
    final frames = await MuxStoryboardHelper.getStoryboard(
      widget.muxPlaybackId!,
    );
    if (frames.isNotEmpty) {
      // Assuming all frames use the same sprite sheet URL for simplicity
      final image = await MuxStoryboardHelper.loadSpriteSheet(
        frames.first.imageUrl,
      );
      if (mounted) {
        setState(() {
          _storyboardFrames = frames;
          _spriteSheet = image;
        });
      }
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    _playPauseFocus.dispose();
    _seekBackFocus.dispose();
    _seekForwardFocus.dispose();
    _lockFocus.dispose();
    _backButtonFocus.dispose();
    _downloadButtonFocus.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          widget.controller.value.isPlaying &&
          !_isLocked &&
          !_isScrubbing) {
        _animationController.reverse().then((_) {
          if (mounted) setState(() => _showControls = false);
        });
      }
    });
  }

  void _showControlsTemporarily() {
    if (_isLocked) return;
    setState(() => _showControls = true);
    _animationController.forward();
    _startHideTimer();
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _showControlsTemporarily();
  }

  void _seekBy(Duration offset) {
    final currentPosition = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final newPosition = currentPosition + offset;
    widget.controller.seekTo(
      Duration(
        milliseconds: newPosition.inMilliseconds.clamp(
          0,
          duration.inMilliseconds,
        ),
      ),
    );
    _showControlsTemporarily();
  }

  void _toggleLock() {
    setState(() => _isLocked = !_isLocked);
    if (!_isLocked) {
      _showControlsTemporarily();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.isTV,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showControlsTemporarily,
        child: Stack(
          children: [
            // Video player
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),

            // Lock overlay
            if (_isLocked) _buildLockOverlay(),

            // Controls overlay
            if (_showControls && !_isLocked)
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildControlsOverlay(),
              ),

            // Scrubbing Preview Overlay
            if (_isScrubbing &&
                _spriteSheet != null &&
                _scrubbingTime != null &&
                _scrubbingOffset != null)
              Positioned(
                bottom: 80, // Above slider
                left: (_scrubbingOffset! - 80).clamp(
                  0,
                  MediaQuery.of(context).size.width - 160,
                ),
                // Center preview (160 width), clamped to screen edges
                child: _buildScrubbingPreview(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrubbingPreview() {
    final frame = _findFrameForTime(_scrubbingTime!.inSeconds.toDouble());
    if (frame == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatDuration(_scrubbingTime!),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 160,
          height: 90,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.black,
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black54)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CustomPaint(
              painter: StoryboardPainter(
                image: _spriteSheet!,
                sourceRect: Rect.fromLTWH(
                  frame.x.toDouble(),
                  frame.y.toDouble(),
                  frame.width.toDouble(),
                  frame.height.toDouble(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  StoryboardFrame? _findFrameForTime(double time) {
    for (final frame in _storyboardFrames) {
      if (time >= frame.startTime && time < frame.endTime) {
        return frame;
      }
    }
    return null;
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0, 0.2, 0.8, 1],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          _buildCenterControls(),
          const Spacer(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (widget.onBackPressed != null)
            _buildFocusableButton(
              icon: Icons.arrow_back,
              onPressed: widget.onBackPressed!,
              focusNode: _backButtonFocus,
              size: 28,
            ),
          const SizedBox(width: 16),
          if (widget.title != null)
            Expanded(
              child: Text(
                widget.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          if (widget.showDownload && widget.onDownload != null) ...[
            _buildFocusableButton(
              icon: Icons.download,
              onPressed: widget.onDownload!,
              focusNode: _downloadButtonFocus,
              size: 28,
            ),
            const SizedBox(width: 16),
          ],
          _buildFocusableButton(
            icon: _isLocked ? Icons.lock : Icons.lock_open,
            onPressed: _toggleLock,
            focusNode: _lockFocus,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    final isPlaying = widget.controller.value.isPlaying;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFocusableButton(
          icon: Icons.replay_10,
          onPressed: () => _seekBy(const Duration(seconds: -10)),
          focusNode: _seekBackFocus,
          size: 56,
        ),
        const SizedBox(width: 48),
        _buildFocusableButton(
          icon: isPlaying ? Icons.pause : Icons.play_arrow,
          onPressed: _togglePlayPause,
          focusNode: _playPauseFocus,
          size: 80,
          isPrimary: true,
        ),
        const SizedBox(width: 48),
        _buildFocusableButton(
          icon: Icons.forward_10,
          onPressed: () => _seekBy(const Duration(seconds: 10)),
          focusNode: _seekForwardFocus,
          size: 56,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(
            _formatDuration(position),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: Theme.of(context).colorScheme.primary,
                    trackShape: const RectangularSliderTrackShape(),
                  ),
                  child: Slider(
                    value: duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0,
                    onChanged: (value) {
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      setState(() {
                        _scrubbingTime = newPosition;
                        _scrubbingOffset = value * constraints.maxWidth;
                      });
                    },
                    onChangeStart: (_) {
                      setState(() => _isScrubbing = true);
                      _showControlsTemporarily();
                    },
                    onChangeEnd: (value) {
                      setState(() => _isScrubbing = false);
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      widget.controller.seekTo(newPosition);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.hd_outlined, color: Colors.white, size: 20),
            tooltip: 'Quality',
            onPressed: widget.onQualityChange,
          ),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLockOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = true);
        _startHideTimer();
      },
      child: Container(
        color: Colors.transparent,
        child: _showControls
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 48,
                      ),
                      onPressed: _toggleLock,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to unlock',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildFocusableButton({
    required IconData icon,
    required VoidCallback onPressed,
    required FocusNode focusNode,
    double size = 48,
    bool isPrimary = false,
  }) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) _showControlsTemporarily();
        setState(() {});
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: isFocused
                ? (Matrix4.identity()..scale(1.15))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPrimary
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: isFocused ? 1 : 0.8)
                  : Colors.black.withValues(alpha: isFocused ? 0.6 : 0.4),
              border: isFocused
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              icon: Icon(icon, color: Colors.white, size: size * 0.6),
              iconSize: size * 0.6,
              padding: EdgeInsets.all(size * 0.2),
              onPressed: onPressed,
            ),
          );
        },
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekBy(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekBy(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      widget.onBackPressed?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class StoryboardPainter extends CustomPainter {
  final ui.Image image;
  final Rect sourceRect;

  StoryboardPainter({required this.image, required this.sourceRect});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      sourceRect,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant StoryboardPainter oldDelegate) {
    return oldDelegate.sourceRect != sourceRect || oldDelegate.image != image;
  }
}
