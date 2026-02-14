import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ransh_app/utils/logger.dart';

class SampleDataSeeder {
  static final List<Map<String, dynamic>> sampleCartoons = [
    {
      'title': 'Jungle Adventures',
      'description':
          'Join the animals on a wild journey through the deep green forest!',
      'category': 'cartoon',
      'type': 'FULL',
      'access_tier': 'FREE',
      'language': 'en',
      'duration_seconds': 600,
      'is_published': true,
      'is_premium': false,

      'thumbnail_url': 'https://picsum.photos/id/237/800/450', // Dog
    },
    {
      'title': 'Space Explorers',
      'description': 'Three friends build a rocket and fly to the moon.',
      'category': 'cartoon',
      'type': 'FULL',
      'access_tier': 'PREMIUM',
      'language': 'en',
      'duration_seconds': 900,
      'is_published': true,
      'is_premium': true,
      'video_url': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      'thumbnail_url': 'https://picsum.photos/id/1002/800/450', // Space/NASA
    },
    {
      'title': 'Underwater World',
      'description': 'Discover the secrets of the colorful coral reef.',
      'category': 'cartoon',
      'type': 'FULL',
      'access_tier': 'FREE',
      'language': 'en',
      'duration_seconds': 450,
      'is_published': true,
      'is_premium': false,

      'thumbnail_url': 'https://picsum.photos/id/1069/800/450', // Jellyfish
    },
    {
      'title': 'Funny Robots',
      'description': 'Beep boop! These robots are learning how to dance.',
      'category': 'cartoon',
      'type': 'FULL',
      'access_tier': 'FREE',
      'language': 'en',
      'duration_seconds': 300,
      'is_published': true,
      'is_premium': false,

      'thumbnail_url':
          'https://picsum.photos/id/1060/800/450', // Kitchen/Coffee (matches robot-ish?)
    },
    {
      'title': 'Magical Forest',
      'description':
          'Fairies and elves protect their home from the grumpy troll.',
      'category': 'stories',
      'type': 'FULL',
      'access_tier': 'PREMIUM',
      'language': 'en',
      'duration_seconds': 1200,
      'is_published': true,
      'is_premium': true,

      'thumbnail_url': 'https://picsum.photos/id/1043/800/450', // Nature
    },
    {
      'title': 'Train Rhymes',
      'description': 'Sing along with Thomas the Train and friends!',
      'category': 'rhymes',
      'type': 'FULL',
      'access_tier': 'FREE',
      'language': 'en',
      'duration_seconds': 180,
      'is_published': true,
      'is_premium': false,

      'thumbnail_url':
          'https://picsum.photos/id/1071/800/450', // Vehicle/Water?
    },
  ];

  static Future<void> seedDatabase() async {
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('content');

    for (final data in sampleCartoons) {
      final docRef = collection.doc(); // Auto-ID
      final entry = {
        ...data,
        'created_at': FieldValue.serverTimestamp(),
        'sort_order': DateTime.now().millisecondsSinceEpoch,
        'mux_asset_id': '', // Placeholder for sample data
        'mux_playback_id': '', // Placeholder for sample data
        'view_count': 0,
      };
      batch.set(docRef, entry);
    }

    try {
      await batch.commit();
      Logger.success('Successfully seeded ${sampleCartoons.length} documents.');
    } catch (e) {
      Logger.error('Failed to seed database: $e');
      rethrow;
    }
  }
}
