import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import 'story_viewer.dart';
import '../../stories/screens/story_camera_screen.dart';

class StorySection extends StatefulWidget {
  const StorySection({super.key});

  @override
  State<StorySection> createState() => _StorySectionState();
}

class _StorySectionState extends State<StorySection> {
  final _apiService = ApiService();
  List<dynamic> _stories = [];
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    try {
      const storage = FlutterSecureStorage();
      final userJson = await storage.read(key: 'user');
      if (userJson != null && mounted) {
        setState(() {
          _currentUser = jsonDecode(userJson);
        });
      }

      final response = await _apiService.get('/stories/feed');
      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        List<dynamic> parsedStories = [];
        if (decoded is List) {
          parsedStories = decoded;
        } else if (decoded is Map && decoded['stories'] is List) {
          parsedStories = decoded['stories'];
        }

        setState(() {
          _stories = parsedStories;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      debugPrint("Story feed loading failed.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addStory() async {
    final bool? published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const StoryCameraScreen(),
      ),
    );

    if (published == true && mounted) {
      _loadData();
    }
  }

  void _openStoryViewer(int index) {
    if (_stories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewer(stories: _stories, initialIndex: index),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = _currentUser?['username'] ?? _currentUser?['anonymous_username'] ?? 'You';
    final myAvatarUrl = _currentUser?['profile_photo_url'] ?? _currentUser?['avatar_url'];

    return SizedBox(
      height: 110,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          // Your Story Bubble (Always visible immediately)
          GestureDetector(
            onTap: _addStory,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: SafeAvatar(
                          avatarUrl: myAvatarUrl,
                          username: myUsername,
                          radius: 28,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Your Story",
                    style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator inline if still fetching community stories
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
                ),
              ),
            ),

          // Community Stories
          ..._stories.asMap().entries.map((entry) {
            final int index = entry.key;
            final story = entry.value;
            final author = story['author_id']?.toString() ?? 'User';
            final authorPhoto = story['author_photo']?.toString();
            final bool isCloseFriends = story['is_close_friends_only'] == true;

            return GestureDetector(
              onTap: () => _openStoryViewer(index),
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isCloseFriends
                            ? const LinearGradient(
                                colors: [Color(0xFF00E676), Color(0xFF1DE9B6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                      ),
                      child: SafeAvatar(
                        avatarUrl: authorPhoto,
                        username: author,
                        radius: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "@$author",
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
