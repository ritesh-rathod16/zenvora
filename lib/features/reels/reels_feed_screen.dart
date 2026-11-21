import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/services/api_service.dart';
import '../../widgets/safe_avatar.dart';
import '../../widgets/follow_button.dart';
import '../../widgets/double_tap_heart.dart';
import '../profile/user_profile_screen.dart';
import 'widgets/reel_options_sheet.dart';

class ReelsFeedScreen extends StatefulWidget {
  const ReelsFeedScreen({super.key});

  @override
  State<ReelsFeedScreen> createState() => _ReelsFeedScreenState();
}

class _ReelsFeedScreenState extends State<ReelsFeedScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _reels = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchReels();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchReels() async {
    try {
      final res = await _apiService.get('/reels/feed');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _reels = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadReel() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    final TextEditingController captionCtrl = TextEditingController();

    final bool? publish = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Create Reel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: captionCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Write a caption...", hintStyle: TextStyle(color: Colors.white38)),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text("Publish"),
          ),
        ],
      ),
    );

    if (publish == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading reel...")));
      try {
        final token = await const FlutterSecureStorage().read(key: 'token');
        final uri = Uri.parse("${ApiService.baseUrl}/reels/upload");
        var request = http.MultipartRequest('POST', uri);
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        request.files.add(await http.MultipartFile.fromPath('file', video.path));
        request.fields['caption'] = captionCtrl.text.trim();

        var streamedRes = await request.send();
        var response = await http.Response.fromStream(streamedRes);

        if (response.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reel published successfully!")));
          _fetchReels();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : _reels.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_collection_outlined, size: 80, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text("No reels posted yet", style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _uploadReel,
                            icon: const Icon(Icons.add),
                            label: const Text("Create Reel"),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                          ),
                        ],
                      ),
                    )
                  : PageView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: _reels.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, index) {
                        return _ReelItemWidget(
                          reel: _reels[index],
                          isActive: index == _currentIndex,
                          apiService: _apiService,
                        );
                      },
                    ),

          // Top Header (Reels | Camera Icon)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Reels", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 24),
                  onPressed: _uploadReel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelItemWidget extends StatefulWidget {
  final dynamic reel;
  final bool isActive;
  final ApiService apiService;

  const _ReelItemWidget({
    required this.reel,
    required this.isActive,
    required this.apiService,
  });

  @override
  State<_ReelItemWidget> createState() => _ReelItemWidgetState();
}

class _ReelItemWidgetState extends State<_ReelItemWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _isReposted = false;
  int _repostsCount = 0;

  String resolveVideoUrl(String videoUrl) {
    final value = videoUrl.trim();
    if (value.isEmpty) {
      throw const FormatException('Video URL is empty');
    }

    final uri = Uri.parse(value);
    if (uri.hasScheme) {
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return uri.toString();
      }
      throw FormatException('Unsupported video URL scheme: ${uri.scheme}');
    }

    return Uri.parse('${ApiService.baseUrl}/').resolve(value).toString();
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reel['is_liked'] == true;
    _likesCount = widget.reel['likes_count'] ?? 0;
    _isReposted = widget.reel['is_reposted'] == true;
    _repostsCount = widget.reel['reposts_count'] ?? 0;

    try {
      final rawUrl = widget.reel['video_url']?.toString() ?? '';
      final String videoUrl = resolveVideoUrl(rawUrl);
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller.setLooping(true);
            if (widget.isActive) _controller.play();
          }
        }).catchError((_) {
          debugPrint("Video playback initialization failed.");
          if (mounted) setState(() => _hasError = true);
        });
    } catch (_) {
      debugPrint("Video URL parsing failed.");
      _hasError = true;
    }
  }

  @override
  void didUpdateWidget(covariant _ReelItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized && !_hasError) {
      if (widget.isActive) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelOptionsSheet(
        reel: widget.reel,
        apiService: widget.apiService,
      ),
    );
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      final reelId = widget.reel['id'] ?? widget.reel['_id'] ?? '';
      await widget.apiService.post('/reels/$reelId/like', {});
      if (_isLiked) {
        widget.apiService.post('/recommendations/events', {
          'content_id': reelId,
          'content_type': 'reel',
          'event_type': 'like',
          'author_id': widget.reel['author_id']?.toString() ?? '',
          'recommendation_source': 'reels'
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleRepost() async {
    setState(() {
      _isReposted = !_isReposted;
      _repostsCount += _isReposted ? 1 : -1;
    });
    try {
      await widget.apiService.post('/reels/${widget.reel['id']}/repost', {});
    } catch (_) {}
  }

  void _showCommentsSheet() {
    final TextEditingController commentCtrl = TextEditingController();
    List comments = widget.reel['comments'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            children: [
              const Text("Comments", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white10),
              Expanded(
                child: comments.isEmpty
                    ? const Center(child: Text("No comments yet.", style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (_, idx) {
                          final c = comments[idx];
                          return ListTile(
                            leading: SafeAvatar(avatarUrl: null, username: c['author_id'] ?? 'User', radius: 16),
                            title: Text("@${c['author_id']}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(c['content'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: "Add a comment...", hintStyle: TextStyle(color: Colors.white38)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF6C63FF)),
                    onPressed: () async {
                      final text = commentCtrl.text.trim();
                      if (text.isEmpty) return;
                      commentCtrl.clear();
                      try {
                        final res = await widget.apiService.post('/reels/${widget.reel['id']}/comment', {'content': text});
                        if (res.statusCode == 200) {
                          final data = jsonDecode(res.body);
                          setModalState(() {
                            comments.add(data['comment']);
                          });
                        }
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.reel['author_id'] ?? 'User';
    final authorPhoto = widget.reel['author_photo'];
    final caption = widget.reel['caption'] ?? '';

    return DoubleTapHeartOverlay(
      onDoubleTap: _toggleLike,
      child: GestureDetector(
        onTap: () {
          if (_isInitialized && !_hasError) {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
          _hasError
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      SizedBox(height: 8),
                      Text("Failed to load video", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                )
              : _isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.6, 1.0],
              ),
            ),
          ),

          // Bottom Left Creator Info & Caption
          Positioned(
            bottom: 30,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfileScreen(username: author)),
                    );
                  },
                  child: Row(
                    children: [
                      SafeAvatar(avatarUrl: authorPhoto, username: author, radius: 20),
                      const SizedBox(width: 10),
                      Text(
                        "@$author",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 12),
                      FollowButton(username: author),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Right Side Action Bar (Like, Comment, Repost, Share)
          Positioned(
            bottom: 40,
            right: 16,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isLiked ? Colors.redAccent : Colors.white,
                    size: 32,
                  ),
                  onPressed: _toggleLike,
                ),
                Text("$_likesCount", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 30),
                  onPressed: _showCommentsSheet,
                ),
                Text("${(widget.reel['comments'] as List? ?? []).length}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                IconButton(
                  icon: Icon(
                    Icons.repeat_rounded,
                    color: _isReposted ? Colors.greenAccent : Colors.white,
                    size: 30,
                  ),
                  onPressed: _toggleRepost,
                ),
                Text("$_repostsCount", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 28),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reel shared successfully!")));
                  },
                ),
                const SizedBox(height: 16),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 28),
                  onPressed: _showOptionsSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
