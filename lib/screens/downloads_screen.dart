import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ransh_app/models/ransh_content.dart';
import 'package:ransh_app/providers/auth_provider.dart';
import 'package:ransh_app/screens/video_player_screen.dart';
import 'package:ransh_app/services/device_type_service.dart';
import 'dart:io'; // Add dart:io import
import 'package:ransh_app/widgets/focusable_card.dart';
import 'package:ransh_app/widgets/shorts_player.dart';

/// Screen to display and manage downloaded videos
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  List<RanshContent> _downloads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);
    final downloadService = ref.read(downloadServiceProvider);
    final downloads = await downloadService.getDownloadedContent();
    if (mounted) {
      setState(() {
        _downloads = downloads;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDownload(RanshContent content) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: const Text(
          'Delete Download',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${content.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final downloadService = ref.read(downloadServiceProvider);
      await downloadService.deleteDownload(content.id);
      await _loadDownloads(); // Refresh list
    }
  }

  void _playVideo(RanshContent content) {
    if (content.isShorts) {
      // Filter for ALL downloaded shorts
      final shortsList = _downloads.where((c) => c.isShorts).toList();
      final initialIndex = shortsList.indexWhere((c) => c.id == content.id);

      final deviceType = ref.read(deviceTypeStateProvider);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShortsPlayer(
            shorts: shortsList,
            initialIndex: initialIndex != -1 ? initialIndex : 0,
            isTV: deviceType == DeviceType.tv,
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VideoPlayerScreen(content: content, isOffline: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ref.watch(deviceTypeStateProvider);
    final isTV = deviceType == DeviceType.tv;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Downloads'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(isTV),
    );
  }

  Widget _buildBody(bool isTV) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.file_download_off,
              size: 64,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            Text(
              'No downloaded videos',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    if (isTV) {
      return GridView.builder(
        padding: const EdgeInsets.all(48),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 16 / 10,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: _downloads.length,
        itemBuilder: (context, index) {
          final content = _downloads[index];
          return _buildDownloadCard(content);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _downloads.length,
      itemBuilder: (context, index) {
        final content = _downloads[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildDownloadListItem(content),
        );
      },
    );
  }

  Widget _buildDownloadCard(RanshContent content) {
    return FocusableCard(
      onTap: () => _playVideo(content),
      onLongPress: () => _deleteDownload(content),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (content.secureThumbnailUrl.isNotEmpty)
            _DownloadThumbnail(
              contentId: content.id,
              remoteUrl: content.secureThumbnailUrl,
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  content.formattedDuration,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => _deleteDownload(content),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadListItem(RanshContent content) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _DownloadThumbnail(
              contentId: content.id,
              remoteUrl: content.thumbnailUrl ?? '',
            ),
          ),
        ),
        title: Text(
          content.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          content.formattedDuration,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => _deleteDownload(content),
        ),
        onTap: () => _playVideo(content),
      ),
    );
  }
}

class _DownloadThumbnail extends ConsumerStatefulWidget {
  final String contentId;
  final String remoteUrl;

  const _DownloadThumbnail({required this.contentId, required this.remoteUrl});

  @override
  ConsumerState<_DownloadThumbnail> createState() => _DownloadThumbnailState();
}

class _DownloadThumbnailState extends ConsumerState<_DownloadThumbnail> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _checkLocalFile();
  }

  Future<void> _checkLocalFile() async {
    final encryptionService = ref.read(encryptionServiceProvider);
    try {
      if (await encryptionService.fileExists('${widget.contentId}.jpg')) {
        final path = await encryptionService.getUnencryptedFilePath(
          '${widget.contentId}.jpg',
        );
        if (mounted) {
          setState(() {
            _localFile = File(path);
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking local thumbnail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: BoxFit.fill,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
      );
    }

    if (widget.remoteUrl.isEmpty) {
      return Container(color: Colors.grey[900]);
    }

    return Image.network(
      widget.remoteUrl,
      fit: BoxFit.fill,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
    );
  }
}
