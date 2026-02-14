import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ransh_app/models/ransh_content.dart';
import 'package:ransh_app/providers/auth_provider.dart';
import 'package:ransh_app/screens/home_screen.dart'; // For ContentCard
import 'package:ransh_app/screens/video_player_screen.dart';
import 'package:ransh_app/services/device_type_service.dart';
import 'package:ransh_app/widgets/focusable_card.dart' hide ContentCard;
import 'package:ransh_app/widgets/shorts_player.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Explicitly request focus for TV after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_searchFocus);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _playVideo(RanshContent content) {
    if (content.isShorts) {
      // Create a list with just this item for shorts player
      // In a real app, you might want to find other shorts from search results
      final deviceType = ref.read(deviceTypeStateProvider);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShortsPlayer(
            shorts: [content],
            initialIndex: 0,
            isTV: deviceType == DeviceType.tv,
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(content: content),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceType = ref.watch(deviceTypeStateProvider);
    final isTV = deviceType == DeviceType.tv;
    final userSession = ref.watch(currentUserSessionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          autofocus: true,
          textInputAction:
              TextInputAction.search, // Show Search button on keyboard
          onSubmitted: (_) {
            // Hide keyboard on submit, results update via onChanged automatically
            // or we could force a "search" state if needed
            _searchFocus.unfocus();
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search cartoons, rhymes...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            FocusableCard(
              // Wrap clear button for TV focus
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
                // Refocus search field after clearing
                FocusScope.of(context).requestFocus(_searchFocus);
              },
              borderRadius: 20,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.clear, color: Colors.white),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('content')
            .where('is_published', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];
          final allContent = allDocs
              .map((doc) => RanshContent.fromFirestore(doc))
              .toList();

          // Client-side filter for flexibility (case-insensitive contains)
          final filtered = _query.isEmpty
              ? <RanshContent>[]
              : allContent.where((content) {
                  final q = _query.toLowerCase();
                  return content.title.toLowerCase().contains(q) ||
                      (content.category?.toLowerCase().contains(q) ?? false) ||
                      (content.tags?.any((t) => t.toLowerCase().contains(q)) ??
                          false);
                }).toList();

          if (_query.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 64, color: Colors.white30),
                  const SizedBox(height: 16),
                  Text(
                    'Search for your favorite videos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No results found for "$_query"',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          return GridView.builder(
            padding: EdgeInsets.all(isTV ? 48 : 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTV
                  ? 4
                  : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
              childAspectRatio: 16 / 11,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final content = filtered[index];
              return ContentCard(
                content: content,
                onTap: () => _playVideo(content),
                userSession: userSession,
              );
            },
          );
        },
      ),
    );
  }
}
