import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:ransh_app/models/user_session.dart'; // Unused
import 'package:ransh_app/services/mux_service.dart';
import 'package:ransh_app/utils/logger.dart'; // Import Logger
import 'package:ransh_app/screens/subscription_screen.dart';
import 'package:ransh_app/screens/admin/subscriptions_tab.dart';
import 'package:ransh_app/utils/sample_data_seeder.dart';
import 'package:ransh_app/services/firebase_seeder.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Admin Dashboard (Mux)'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.sync,
              color: Theme.of(context).colorScheme.secondary,
            ),
            tooltip: 'Sync System Config',
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Syncing config to Firebase...'),
                  ),
                );
                await FirebaseSeeder().seedAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Config Synced Successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                }
              }
            },
          ),
          // Subscription management button
          IconButton(
            icon: Icon(
              Icons.workspace_premium,
              color: Theme.of(context).colorScheme.secondary,
            ),
            tooltip: 'Subscription Plans',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload), text: 'Upload'),
            Tab(icon: Icon(Icons.video_library), text: 'Content'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.workspace_premium), text: 'Subscriptions'),
          ],
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UploadTab(),
          _ContentTab(),
          _UsersTab(),
          SubscriptionsTab(),
        ],
      ),
    );
  }
}

class _UploadTab extends ConsumerStatefulWidget {
  const _UploadTab();

  @override
  ConsumerState<_UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends ConsumerState<_UploadTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController();

  String _category = 'Cartoon';
  String _type = 'FULL';
  String _access = 'FREE';
  String _language = 'English';

  bool _isUploading = false;
  String? _statusMessage;
  PlatformFile? _selectedVideo;
  PlatformFile? _selectedCover;

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedVideo = result.files.first;
      });
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedCover = result.files.first;
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = 'Creating upload session...';
    });

    try {
      final muxService = ref.read(muxServiceProvider);

      // 1. Create direct upload
      setState(() {
        _statusMessage = 'Preparing Mux upload...';
      });

      final uploadData = await muxService.createDirectUpload();
      final uploadUrl = uploadData['upload_url'] as String;
      final uploadId = uploadData['upload_id'] as String;

      Logger.info('Mux upload created: $uploadId');

      setState(() {
        _statusMessage = 'Uploading to Mux...';
      });

      // 2. Upload video file
      final fileBytes = kIsWeb ? _selectedVideo!.bytes : null;
      final filePath = !kIsWeb ? _selectedVideo!.path : null;

      if (filePath == null && fileBytes == null) {
        throw Exception('File path or bytes not available');
      }

      await muxService.uploadVideo(
        uploadUrl: uploadUrl,
        file: filePath != null ? File(filePath) : null,
        fileBytes: fileBytes,
        onProgress: (p) {
          final progress = (p * 100).toStringAsFixed(0);
          if (mounted) {
            setState(() {
              _statusMessage = 'Uploading to Mux... $progress%';
            });
          }
        },
      );

      Logger.success('Video uploaded to Mux');

      setState(() {
        _statusMessage = 'Waiting for Mux to process video...';
      });

      // 3. Wait for upload to process into an asset
      final assetId = await muxService.waitForUploadToBecomeAsset(
        uploadId,
        pollInterval: const Duration(seconds: 2),
      );

      Logger.info('Asset ID created: $assetId');

      // 4. Wait for asset to be ready
      final asset = await muxService.waitForAssetReady(
        assetId,
        pollInterval: const Duration(seconds: 2),
      );
      final playbackId = muxService.getPlaybackId(asset);

      if (playbackId == null || playbackId.isEmpty) {
        throw Exception('Failed to get playback ID from Mux');
      }

      Logger.success('Asset ready: $assetId, Playback ID: $playbackId');

      // 5. Handle custom thumbnail (Base64 Storage)
      String? customThumbnailUrl;
      if (_selectedCover != null) {
        setState(() {
          _statusMessage = 'Encoding custom thumbnail...';
        });

        final coverPath = !kIsWeb ? _selectedCover!.path : null;
        if (coverPath != null) {
          try {
            final bytes = await File(coverPath).readAsBytes();
            final base64Image = base64Encode(bytes);
            customThumbnailUrl = 'data:image/jpeg;base64,$base64Image';
            Logger.success('Custom thumbnail encoded to Base64');
          } catch (e) {
            Logger.warning('Custom thumbnail encoding failed: $e');
          }
        }
      }

      setState(() {
        _statusMessage = 'Saving metadata to Firestore...';
      });

      // 6. Save to Firestore
      final duration =
          int.tryParse(_durationController.text) ??
          (asset['duration'] as num?)?.toInt() ??
          0;

      // Map language name to code
      String langCode = 'en';
      switch (_language) {
        case 'Hindi':
          langCode = 'hi';
          break;
        case 'Marathi':
          langCode = 'mr';
          break;
        default:
          langCode = 'en';
      }

      await FirebaseFirestore.instance.collection('content').add({
        'title': _titleController.text,
        'description': _descController.text,
        'category': _category.toLowerCase(),
        'content_type': _type.toLowerCase(), // 'full' or 'shorts'
        'access_level': _access.toLowerCase(), // 'free' or 'premium'
        'language': langCode,
        'duration': duration,
        'mux_asset_id': assetId,
        'mux_playback_id': playbackId,
        'thumbnail_url':
            customThumbnailUrl ?? muxService.getThumbnailUrl(playbackId),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'sort_order': DateTime.now().millisecondsSinceEpoch,
        'is_published': true,
        'view_count': 0,
      });

      Logger.success('Content saved to Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e, stackTrace) {
      Logger.error('Upload Error: $e');
      debugPrint('Stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }

      // Detailed error analysis for troubleshooting
      if (e is FirebaseException) {
        Logger.error('Firebase Error Code: ${e.code}');
        Logger.error('Firebase Message: ${e.message}');
        if (e.code == 'permission-denied') {
          Logger.error(
            'PERMISSION DENIED: Check Firestore Rules for "content" collection.',
          );
          Logger.error(
            'Current User: ${FirebaseAuth.instance.currentUser?.email}',
          );
          Logger.error('User UID: ${FirebaseAuth.instance.currentUser?.uid}');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descController.clear();
    _durationController.clear();
    setState(() {
      _selectedVideo = null;
      _selectedCover = null;
      _statusMessage = null;
      _category = 'Cartoon';
      _type = 'FULL';
      _access = 'FREE';
      _language = 'English';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Select Video & Select Cover
            Row(
              children: [
                Expanded(
                  child: _buildSelectionCard(
                    title: _selectedVideo != null
                        ? 'Video Selected'
                        : 'Select Video',
                    icon: Icons.movie,
                    color: Theme.of(context).colorScheme.primary,
                    isSelected: _selectedVideo != null,
                    onTap: _isUploading ? null : _pickVideo,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildSelectionCard(
                        title: _selectedCover != null
                            ? 'Cover Selected'
                            : 'Select Cover',
                        icon: Icons.image,
                        color: Theme.of(context).colorScheme.secondary,
                        isSelected: _selectedCover != null,
                        onTap: _isUploading ? null : _pickCover,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Recommended: 16:9 Landscape',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            _buildTextField(
              controller: _titleController,
              label: 'Title',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Title is required';
                if (v.length < 3) return 'Title must be at least 3 characters';
                if (v.length > 100)
                  return 'Title must be less than 100 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descController,
              label: 'Description',
              maxLines: 3,
              validator: (v) {
                if (v != null && v.length > 500) {
                  return 'Description must be less than 500 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Duration
            _buildTextField(
              controller: _durationController,
              label: 'Duration (Seconds)',
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null; // Optional field
                final duration = int.tryParse(v);
                if (duration == null) return 'Please enter a valid number';
                if (duration < 0) return 'Duration cannot be negative';
                if (duration > 86400) return 'Duration cannot exceed 24 hours';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Type & Access Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Type',
                    value: _type,
                    items: ['FULL', 'SHORTS', 'TRAILER'],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    label: 'Access',
                    value: _access,
                    items: ['FREE', 'PREMIUM'],
                    onChanged: (v) => setState(() => _access = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Language & Category Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Language',
                    value: _language,
                    items: ['English', 'Hindi', 'Marathi'],
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    label: 'Category',
                    value: _category,
                    items: [
                      'Cartoon',
                      'Movies',
                      'Shorts',
                      'Learning',
                      'Rhymes',
                      'Stories',
                    ],
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
              ],
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Upload Button
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary, // Saffron
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.5),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'UPLOAD CONTENT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          // Gradient background like screenshot
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [color.withOpacity(0.6), color.withOpacity(0.3)]
                : [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle : icon,
              color: isSelected ? Colors.white : color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: Theme.of(context).cardColor,
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              items: items.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Content tab to view/delete existing content
class _ContentTab extends ConsumerWidget {
  const _ContentTab();

  Future<void> _deleteContent(
    BuildContext context,
    WidgetRef ref,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: const Text(
          'Delete Video?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${data['title']}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete from Mux
        final muxAssetId = data['mux_asset_id'];
        if (muxAssetId != null) {
          final muxService = ref.read(muxServiceProvider);
          await muxService.deleteAsset(muxAssetId);
        }

        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('content')
            .doc(docId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }

  Future<void> _seedData(BuildContext context) async {
    try {
      await SampleDataSeeder.seedDatabase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample data seeded successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error seeding data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('content')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No content uploaded yet',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_to_photos),
                  label: const Text('Seed Sample Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () async {
                    // Lazy import logic or direct call if imported
                    // We will fix imports in next step
                    await _seedData(context);
                  },
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black26,
                    child: data['thumbnail_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              data['thumbnail_url'],
                              fit: BoxFit.cover,
                              headers: const {
                                'Cache-Control': 'no-cache',
                                'Pragma': 'no-cache',
                              },
                              errorBuilder: (context, error, stackTrace) {
                                Logger.error(
                                  'Thumbnail Error for ${data['title']}: $error',
                                );
                                return const Icon(
                                  Icons.movie,
                                  color: Colors.white54,
                                );
                              },
                            ),
                          )
                        : const Icon(Icons.movie, color: Colors.white54),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['title'] ?? 'Untitled',
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data['is_premium'] == true)
                      const Tooltip(
                        message: 'Premium Content',
                        child: Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.workspace_premium,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  data['category'] ?? 'Uncategorized',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteContent(context, ref, doc.id, data),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// User management tab
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _emailController = TextEditingController();

  Future<void> _promoteUser(String email) async {
    if (email.isEmpty) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found with this email')),
          );
        }
        return;
      }

      final doc = query.docs.first;
      await doc.reference.update({'role': 'admin', 'is_admin': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doc['display_name']} is now an Admin')),
        );
        _emailController.clear();
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _revokeAdmin(String docId, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'role': 'user',
        'is_admin': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoked admin rights for $name')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Add Admin', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the email of the user you want to promote to Admin.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'User Email',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _promoteUser(_emailController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAdminDialog,
        icon: const Icon(Icons.add_moderator),
        label: const Text('Add Admin'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            // .orderBy('last_login', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No users found',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final email = data['email'] as String? ?? 'No Email';
              final name = data['display_name'] as String? ?? 'No Name';
              final photoUrl = data['photo_url'] as String?;
              final subscriptionPlan = data['subscription_plan'] as String?;

              final role = data['role'] as String? ?? 'user';
              final isAdmin = role == 'admin' || (data['is_admin'] == true);

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: isAdmin
                      ? BorderSide(color: Colors.amber.withOpacity(0.5))
                      : BorderSide.none,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAdmin
                        ? Colors.amber
                        : Theme.of(context).colorScheme.primary,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white)),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_user,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '$email\nPlan: ${subscriptionPlan ?? "Free"}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    onSelected: (value) {
                      if (value == 'revoke') {
                        _revokeAdmin(doc.id, name);
                      } else if (value == 'promote') {
                        _promoteUser(
                          email,
                        ); // Re-use promote for existing list item
                      }
                    },
                    itemBuilder: (context) => [
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'revoke',
                          child: Text(
                            'Revoke Admin Access',
                            style: TextStyle(color: Colors.red),
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'promote',
                          child: Text('Make Admin'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
