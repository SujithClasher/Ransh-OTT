import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ransh_app/providers/ui_providers.dart';
import 'package:ransh_app/widgets/language_selector.dart';
import 'package:ransh_app/models/ransh_content.dart';
import 'package:ransh_app/providers/auth_provider.dart';
import 'package:ransh_app/screens/admin/admin_dashboard.dart';
import 'package:ransh_app/screens/downloads_screen.dart';
import 'package:ransh_app/screens/search_screen.dart';
import 'package:ransh_app/screens/settings_screen.dart';
import 'package:ransh_app/screens/subscription_screen.dart';
import 'package:ransh_app/screens/profile_picture_screen.dart';
import 'package:ransh_app/screens/video_player_screen.dart';
import 'package:ransh_app/services/device_type_service.dart';
import 'package:ransh_app/widgets/focusable_card.dart';
import 'package:ransh_app/widgets/parental_gate.dart';
import 'package:ransh_app/models/user_session.dart'; // Added import
import 'package:ransh_app/widgets/shorts_player.dart';
import 'package:ransh_app/widgets/hero_banner.dart';
import 'package:ransh_app/widgets/content_list.dart';
import 'package:ransh_app/widgets/ransh_image.dart';

/// Home screen with content grid
/// Adapts layout for Mobile, Tablet, and TV
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userSession = ref.watch(currentUserSessionProvider).valueOrNull;
    final deviceType = ref.watch(deviceTypeStateProvider);
    final isTV = deviceType == DeviceType.tv;

    // UI State
    final selectedLang = ref.watch(selectedLanguageProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Pure black for OLED/TV
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(
              user?.displayName,
              isTV,
              userSession?.isAdmin ?? false,
              selectedLang,
            ),
            if (!isTV) _buildCategoryBar(selectedCategory),
            Expanded(
              child: _buildContentGrid(
                isTV,
                selectedLang,
                selectedCategory,
                userSession,
              ),
            ),
          ],
        ),
      ),
      // FAB kept for mobile if explicit globe needed, but we put it in AppBar now mostly.
      // Keeping it as secondary access or removing if redundant.
      // User requested "Globe Icon" in Home Header (AppBar).
      // So I will hide FAB or make it do something else, but strictly complying:
      // "Global Toggle: A 'Language Globe Icon' must be always visible in the Home Header."
      // So removing FAB language toggle to avoid clutter.
    );
  }

  Widget _buildAppBar(
    String? userName,
    bool isTV,
    bool isAdmin,
    String currentLang,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTV ? 48 : 12, // Reduced mobile padding
        vertical: isTV ? 24 : 12,
      ),
      child: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary, // Saffron
                  const Color(0xFFCC7A00), // Darker Saffron for gradient
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/app_icon.jpg',
                width: 32,
                height: 32,
                cacheWidth: 100, // Optimize memory usage
              ),
            ),
          ),
          SizedBox(width: isTV ? 12 : 8), // Reduced gap
          const Text(
            'Ransh',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // Search Action
          FocusableCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            borderRadius: 20,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.search, color: Colors.white),
            ),
          ),
          SizedBox(width: isTV ? 12 : 4), // Tight gap
          // Downloads Action
          FocusableCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
            borderRadius: 20,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.download, color: Colors.white),
            ),
          ),
          SizedBox(width: isTV ? 16 : 8), // Reduced gap
          // Language selector (Mobile & TV)
          FocusableCard(
            onTap: _showLanguageSelector,
            borderRadius: 20,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTV ? 12 : 8,
                vertical: 8,
              ), // Compact
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    const Color(0xFF8B4500).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  // Globe Icon
                  const Icon(Icons.language, color: Colors.white, size: 20),

                  // Show text only if selected or always?
                  SizedBox(width: isTV ? 8 : 4),
                  Text(
                    currentLang.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: isTV ? 16 : 8), // Reduced gap
          // User avatar with profile picture
          if (userName != null)
            FocusableCard(
              onTap: () => _showUserMenu(isAdmin),
              borderRadius: 20,
              child: _buildUserAvatar(userName),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String selectedCategory) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: contentCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = contentCategories[index];
          final isSelected = category == selectedCategory;
          return FocusableCard(
            onTap: () {
              ref.read(selectedCategoryProvider.notifier).state = category;
            },
            borderRadius: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white24,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentGrid(
    bool isTV,
    String selectedLang,
    String selectedCategory,
    UserSession? userSession,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('content')
          .where('is_published', isEqualTo: true)
          .where('language', isEqualTo: selectedLang)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        var allContent = docs
            .map((d) => RanshContent.fromFirestore(d))
            .toList();

        // Apply Category Filter locally
        if (selectedCategory != 'All') {
          allContent = allContent.where((c) {
            return (c.category ?? '').toLowerCase() ==
                selectedCategory.toLowerCase();
          }).toList();
        }

        if (allContent.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.ondemand_video, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No content found for $selectedLang',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          );
        }

        // Logic for Hero Content: Pick the latest Premium, or just the latest item
        RanshContent? heroContent;
        if (allContent.isNotEmpty) {
          // Prefer premium for Hero, else first
          heroContent = allContent.firstWhere(
            (c) => c.isPremium,
            orElse: () => allContent.first,
          );
        }

        return CustomScrollView(
          slivers: [
            // Hero
            if (heroContent != null)
              SliverToBoxAdapter(
                child: HeroBanner(
                  content: heroContent,
                  onPlay: () => _playContent(heroContent!, isTV, allContent),
                  onDetails: () {
                    // Optional: Show details dialog
                  },
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Content Rows
            if (selectedCategory == 'All') ...[
              // Trending / Latest
              SliverToBoxAdapter(
                child: ContentList(
                  title: 'Trending Now',
                  contentList: allContent.take(10).toList(),
                  onContentTap: (c) => _playContent(c, isTV, allContent),
                  isTV: isTV,
                  userSession: userSession,
                ),
              ),
              // Category chunks
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  // Skip 'All' in the loop
                  final categoryName =
                      contentCategories[index + 1]; // +1 to skip All
                  final categoryContent = allContent
                      .where(
                        (c) =>
                            (c.category ?? '').toLowerCase() ==
                            categoryName.toLowerCase(),
                      )
                      .toList();

                  if (categoryContent.isEmpty) return const SizedBox.shrink();

                  return ContentList(
                    title: categoryName,
                    contentList: categoryContent,
                    onContentTap: (c) => _playContent(c, isTV, categoryContent),
                    isTV: isTV,
                    userSession: userSession,
                  );
                }, childCount: contentCategories.length - 1),
              ),
            ] else ...[
              // Specific Category Grid or List
              SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final content = allContent[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ContentCard(
                      content: content,
                      onTap: () => _playContent(content, isTV, allContent),
                      userSession: userSession,
                    ),
                  );
                }, childCount: allContent.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTV ? 4 : 2,
                  childAspectRatio: 16 / 9,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  void _playContent(
    RanshContent content,
    bool isTV,
    List<RanshContent> contextList,
  ) async {
    // 1. Check for Premium Access
    if (content.isPremium) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check user document for subscription status
      // We do a fresh fetch to ensure we have the latest status
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isSubscribed = doc.data()?['subscription_status'] == 'active';
      final isAdmin = doc.data()?['role'] == 'admin';

      if (!isSubscribed && !isAdmin) {
        if (!mounted) return;

        // Direct redirection to subscription screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
        );
        return;
      }
    }

    if (content.isShorts) {
      // Filter for ALL shorts from the current list context
      final shortsList = contextList.where((c) => c.isShorts).toList();
      final initialIndex = shortsList.indexWhere((c) => c.id == content.id);

      // For shorts, we launch a vertical scrolling player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShortsPlayer(
            shorts: shortsList, // Pass FULL list for scrolling
            initialIndex: initialIndex != -1 ? initialIndex : 0,
            isTV: isTV,
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      // For full videos
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(content: content),
        ),
      );
    }
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => const LanguageSelectorDialog(),
    );
  }

  void _showUserMenu(bool isAdmin) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'admin'),
              ),
            ListTile(
              leading: Icon(
                Icons.account_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(
                'Change Profile Picture',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'profile'),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'settings'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'signout'),
            ),
          ],
        ),
      ),
    );

    if (result == 'signout') {
      // Execute sign out directly to avoid provider caching issues
      final authService = ref.read(authServiceProvider);
      final sessionSentinel = ref.read(sessionSentinelProvider);
      final subscriptionService = ref.read(subscriptionServiceProvider);

      final userId = authService.currentUserId;
      if (userId != null) {
        await sessionSentinel.clearSession(userId);
      }
      await subscriptionService.clearCache();
      await authService.signOut();

      if (mounted) {
        ref.read(sessionActiveProvider.notifier).state = false;
      }
    } else if (result == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePictureScreen()),
      );
    } else if (result == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    } else if (result == 'admin') {
      // Check Parental Gate
      final passed = await showParentalGate(context);
      if (passed) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      }
    }
  }

  Widget _buildUserAvatar(String userName) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final profilePicture = data?['profile_picture'] as String?;
        final isPremium = data?['subscription_status'] == 'active';

        Widget avatar;
        if (profilePicture != null && profilePicture.isNotEmpty) {
          // Show selected avatar
          final assetPath = 'assets/avatars/avatar_$profilePicture.png';
          avatar = CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage: ResizeImage(
              AssetImage(assetPath),
              width: 150, // Optimize avatar
            ),
          );
        } else {
          // Show initial
          avatar = CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (isPremium) {
          return Container(
            padding: const EdgeInsets.all(2.5), // Space for the ring
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary, // Amber Accent
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: avatar,
          );
        }

        return avatar;
      },
    );
  }
}

class ContentCard extends StatelessWidget {
  final RanshContent content;
  final VoidCallback onTap;
  final UserSession? userSession;

  const ContentCard({
    super.key,
    required this.content,
    required this.onTap,
    this.userSession,
  });

  @override
  Widget build(BuildContext context) {
    // Only show premium UI if content is premium AND user is NOT subscribed
    final showPremiumUI =
        content.isPremium &&
        !(userSession?.hasActiveSubscription ?? false) &&
        !(userSession?.isAdmin ?? false);

    return FocusableCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: showPremiumUI
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary, // Amber Accent
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  10,
                ), // Slightly less than container
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    content.secureThumbnailUrl.isNotEmpty
                        ? RanshImage(
                            imageUrl: content.secureThumbnailUrl,
                            fit: BoxFit.fill,
                            errorWidget: Container(
                              color: Colors.grey[900],
                              child: const Icon(
                                Icons.movie,
                                color: Colors.white24,
                                size: 48,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[900],
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white24,
                              size: 48,
                            ),
                          ),
                    if (showPremiumUI)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, color: Colors.black, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (content.isShorts)
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(
                          Icons.smartphone,
                          color: Colors.white,
                          size: 20,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              content.title,
              style: TextStyle(
                color: showPremiumUI
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.white,
                fontWeight: showPremiumUI ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
