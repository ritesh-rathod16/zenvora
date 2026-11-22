import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import '../../profile/user_profile_screen.dart';
import '../../stories/models/music_track_model.dart';
import '../../stories/widgets/music_sticker_widget.dart';

class StoryViewer extends StatefulWidget {
  final List<dynamic> stories;
  final int initialIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late PageController _pageController;
  late AnimationController _animController;

  int _currentIndex = 0;
  String? _currentUsername;
  bool _isPaused = false;
  bool _isLiked = false;
  int _likesCount = 0;

  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });

    _loadCurrentUserAndStory();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndStory() async {
    const storage = FlutterSecureStorage();
    final userJson = await storage.read(key: 'user');
    if (userJson != null) {
      final user = jsonDecode(userJson);
      _currentUsername = user['username'] ?? user['anonymous_username'];
    }

    _loadCurrentStoryState();
  }

  void _loadCurrentStoryState() {
    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) return;

    final story = widget.stories[_currentIndex];
    final String storyId = story['id'] ?? story['_id'] ?? '';

    setState(() {
      _isLiked = story['is_liked'] == true;
      _likesCount = story['likes_count'] ?? 0;
    });

    _animController.stop();
    _animController.reset();
    _animController.forward();

    // Track view in backend
    if (storyId.isNotEmpty) {
      _apiService.post('/stories/$storyId/view', {});
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadCurrentStoryState();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _loadCurrentStoryState();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _pauseStory() {
    setState(() => _isPaused = true);
    _animController.stop();
  }

  void _resumeStory() {
    setState(() => _isPaused = false);
    _animController.forward();
  }

  Future<void> _toggleLike() async {
    final story = widget.stories[_currentIndex];
    final String storyId = story['id'] ?? story['_id'] ?? '';
    if (storyId.isEmpty) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await _apiService.post('/stories/$storyId/like', {});
    } catch (_) {}
  }

  Future<void> _sendEmojiReaction(String emoji) async {
    final story = widget.stories[_currentIndex];
    final String storyId = story['id'] ?? story['_id'] ?? '';
    if (storyId.isEmpty) return;

    try {
      await _apiService.post('/stories/$storyId/react', {'emoji': emoji});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sent $emoji reaction to DM!")),
        );
      }
    } catch (_) {}
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final story = widget.stories[_currentIndex];
    final String storyId = story['id'] ?? story['_id'] ?? '';
    if (storyId.isEmpty) return;

    _replyController.clear();
    FocusScope.of(context).unfocus();
    _resumeStory();

    try {
      await _apiService.post('/stories/$storyId/reply', {'text': text});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story reply sent to DM!")),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteStory() async {
    final story = widget.stories[_currentIndex];
    final String storyId = story['id'] ?? story['_id'] ?? '';
    if (storyId.isEmpty) return;

    try {
      await _apiService.delete('/stories/$storyId');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story deleted successfully")),
        );
      }
    } catch (_) {}
  }

  void _showViewersList() async {
    _pauseStory();
    final story = widget.stories[_currentIndex];
    final String storyId = story['id'] ?? story['_id'] ?? '';

    List<dynamic> viewers = [];
    try {
      final res = await _apiService.get('/stories/$storyId/viewers');
      if (res.statusCode == 200) {
        viewers = jsonDecode(res.body);
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Story Viewers (${viewers.length})",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            if (viewers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text("No views yet", style: TextStyle(color: Colors.white38))),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: viewers.length,
                  itemBuilder: (context, index) {
                    final v = viewers[index];
                    final uname = v['username'] ?? 'User';
                    return ListTile(
                      leading: SafeAvatar(
                        avatarUrl: v['profile_photo_url'],
                        username: uname,
                        radius: 18,
                      ),
                      title: Text("@$uname", style: const TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: v['has_liked'] == true
                          ? const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UserProfileScreen(username: uname)),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ).then((_) => _resumeStory());
  }

  String _resolveMediaUrl(String mediaUrl) {
    final value = mediaUrl.trim();
    if (value.isEmpty) return '';

    final uri = Uri.parse(value);
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return uri.toString();
    }

    return Uri.parse('${ApiService.baseUrl}/').resolve(value).toString();
  }

  Widget _buildInteractiveStickers(Map<String, dynamic> s) {
    List<Widget> overlays = [];

    // 1. Music Track Sticker
    if (s['music_track'] != null) {
      final trackData = s['music_track'];
      final track = MusicTrackModel.fromJson(trackData);
      overlays.add(
        Positioned(
          top: 90,
          left: 20,
          child: MusicStickerWidget(track: track, style: MusicStickerStyle.albumArtCard),
        ),
      );
    }

    // 2. Poll Sticker
    if (s['poll'] != null) {
      final poll = s['poll'];
      final question = poll['question'] ?? 'Poll';
      final List options = poll['options'] ?? [];
      overlays.add(
        Positioned(
          bottom: 140,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...options.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: () async {
                        _pauseStory();
                        try {
                          final res = await _apiService.post('/stories/${s['id'] ?? s['_id']}/poll-vote', {'option_index': idx});
                          if (res.statusCode == 200 && mounted) {
                            setState(() {
                              s['poll'] = jsonDecode(res.body)['poll'];
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote recorded!")));
                          }
                        } catch (_) {}
                        _resumeStory();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A2E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(opt.toString()),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Quiz Sticker
    if (s['quiz'] != null) {
      final quiz = s['quiz'];
      final question = quiz['question'] ?? 'Quiz';
      final List options = quiz['options'] ?? [];
      overlays.add(
        Positioned(
          bottom: 140,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.pinkAccent, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(question, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...options.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: () async {
                        _pauseStory();
                        try {
                          final res = await _apiService.post('/stories/${s['id'] ?? s['_id']}/quiz-vote', {'option_index': idx});
                          if (res.statusCode == 200 && mounted) {
                            final data = jsonDecode(res.body);
                            final isCorrect = data['is_correct'];
                            setState(() {
                              s['quiz'] = data['quiz'];
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isCorrect ? "Correct! 🎉" : "Incorrect ❌")),
                            );
                          }
                        } catch (_) {}
                        _resumeStory();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A2E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(opt.toString()),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(children: overlays);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const SizedBox();
    final story = widget.stories[_currentIndex];
    final authorId = story['author_id']?.toString() ?? 'User';
    final authorPhoto = story['author_photo']?.toString();
    final bool isMe = _currentUsername == authorId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onLongPressStart: (_) => _pauseStory(),
          onLongPressEnd: (_) => _resumeStory(),
          child: Stack(
            children: [
              // Media Viewer
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.stories.length,
                itemBuilder: (context, index) {
                  final s = widget.stories[index];
                  final mediaUrl = _resolveMediaUrl(s['media_url']?.toString() ?? '');
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
                        ),
                      ),
                      _buildInteractiveStickers(s),
                    ],
                  );
                },
              ),

              // Tap Regions for Next / Previous Story
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _previousStory,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _nextStory,
                    ),
                  ),
                ],
              ),

              // Top Progress Bars & Header (hidden when paused)
              if (!_isPaused)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: [
                      // Progress Bars
                      Row(
                        children: List.generate(widget.stories.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                  double progress = 0.0;
                                  if (index < _currentIndex) {
                                    progress = 1.0;
                                  } else if (index == _currentIndex) {
                                    progress = _animController.value;
                                  }
                                  return LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 2.5,
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      // User Header Row
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => UserProfileScreen(username: authorId)),
                              );
                            },
                            child: Row(
                              children: [
                                SafeAvatar(
                                  avatarUrl: authorPhoto,
                                  username: authorId,
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "@$authorId • ${story['time_ago'] ?? 'Just now'}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (story['is_close_friends_only'] == true) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text("Close Friends", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (isMe)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white70),
                              onPressed: _deleteStory,
                            ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Bottom Footer Actions (Reply, Emojis, Like, Viewers count)
              if (!_isPaused)
                Positioned(
                  bottom: 16,
                  left: 12,
                  right: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick Emoji Bar
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: ['❤️', '🔥', '😂', '😮', '👏'].map((emoji) {
                              return GestureDetector(
                                onTap: () => _sendEmojiReaction(emoji),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Message Input or Viewers Button
                      if (isMe)
                        ElevatedButton.icon(
                          onPressed: _showViewersList,
                          icon: const Icon(Icons.remove_red_eye_rounded, size: 18, color: Colors.white),
                          label: Text(
                            "Seen by ${story['views_count'] ?? 0} people",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: TextField(
                                  controller: _replyController,
                                  onTap: _pauseStory,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendReply(),
                                  decoration: InputDecoration(
                                    hintText: "Send message to @$authorId...",
                                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    border: InputBorder.none,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF), size: 18),
                                      onPressed: _sendReply,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: _isLiked ? Colors.redAccent : Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: _toggleLike,
                                ),
                                if (_likesCount > 0)
                                  Text(
                                    "$_likesCount",
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
