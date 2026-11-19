import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import '../../../widgets/follow_button.dart';
import '../../profile/user_profile_screen.dart';
import '../models/post_model.dart';
import 'confession_post.dart';
import 'poll_post.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final ApiService _apiService = ApiService();
  late bool _isLiked;
  late int _likesCount;
  late int _repliesCount;
  late bool _isReposted;
  late int _repostsCount;
  bool _isSaved = false;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likes;
    _repliesCount = widget.post.repliesCount;
    _isReposted = widget.post.isReposted;
    _repostsCount = widget.post.repostsCount;
    _loadMyUsername();
  }

  Future<void> _loadMyUsername() async {
    const storage = FlutterSecureStorage();
    final userJson = await storage.read(key: 'user');
    if (userJson != null) {
      final u = jsonDecode(userJson);
      if (mounted) {
        setState(() {
          _myUsername = u['username'] ?? u['anonymous_username'];
        });
      }
    }
  }

  void _navigateToProfile(String username) {
    if (username.isEmpty || username.toLowerCase() == 'anonymous') return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
  }

  Future<void> _toggleLike() async {
    final nextLiked = !_isLiked;
    setState(() {
      _isLiked = nextLiked;
      _likesCount += nextLiked ? 1 : -1;
      if (_likesCount < 0) _likesCount = 0;
    });

    try {
      final res = await _apiService.post('/posts/${widget.post.id}/like', {});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _isLiked = data['is_liked'] ?? _isLiked;
            _likesCount = data['likes_count'] ?? _likesCount;
          });
        }
      }
    } catch (e) {
      debugPrint("Like error: $e");
    }
  }

  Future<void> _toggleRepost() async {
    final nextRepost = !_isReposted;
    setState(() {
      _isReposted = nextRepost;
      _repostsCount += nextRepost ? 1 : -1;
      if (_repostsCount < 0) _repostsCount = 0;
    });

    try {
      final res = await _apiService.post('/posts/${widget.post.id}/repost', {});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _isReposted = data['is_reposted'] ?? _isReposted;
            _repostsCount = data['reposts_count'] ?? _repostsCount;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isReposted ? "Reposted to your profile" : "Repost removed"),
              backgroundColor: const Color(0xFF1A1A2E),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Repost error: $e");
    }
  }



  void _toggleSave() {
    setState(() => _isSaved = !_isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? "Post saved to your collection" : "Post removed from saved"),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- Likers Bottom Sheet ---
  void _showLikersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder(
          future: _apiService.get('/posts/${widget.post.id}/likers'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
              );
            }
            if (snapshot.hasError || snapshot.data?.statusCode != 200) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text("Could not load likers", style: TextStyle(color: Colors.white70))),
              );
            }
            final List likers = jsonDecode(snapshot.data!.body);
            if (likers.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text("No likes yet. Be the first!", style: TextStyle(color: Colors.white60))),
              );
            }
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      "Likes",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: likers.length,
                      itemBuilder: (context, idx) {
                        final u = likers[idx];
                        final username = u['username'] ?? 'User';
                        return ListTile(
                          leading: SafeAvatar(
                            avatarUrl: u['profile_photo_url'],
                            username: username,
                            radius: 20,
                          ),
                          title: Text(
                            u['display_name'] ?? username,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "@$username",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _navigateToProfile(username);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Comments Bottom Sheet ---
  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _CommentsSheet(
          postId: widget.post.id,
          apiService: _apiService,
          onCommentCountChanged: (count) {
            setState(() => _repliesCount = count);
          },
          onNavigateToProfile: _navigateToProfile,
        );
      },
    );
  }

  // --- Share Post Bottom Sheet ---
  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _ShareSheet(
          postId: widget.post.id,
          postContent: widget.post.content,
          apiService: _apiService,
        );
      },
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: Colors.white,
              ),
              title: Text(_isSaved ? "Remove from Saved" : "Save Post", style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _toggleSave();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: const Text("Share to DM", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showShareSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Colors.white),
              title: const Text("Copy Link", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: "https://zenvora.app/posts/${widget.post.id}"));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Link copied to clipboard")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.redAccent),
              title: const Text("Report Post", style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Post reported to moderators.")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repost banner if applicable
            if (widget.post.isRepost && widget.post.originalAuthorId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white.withValues(alpha: 0.04),
                child: Row(
                  children: [
                    const Icon(Icons.repeat_rounded, size: 14, color: Colors.greenAccent),
                    const SizedBox(width: 6),
                    Text(
                      "Reposted from ",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () => _navigateToProfile(widget.post.originalAuthorId!),
                      child: Text(
                        "@${widget.post.originalAuthorId}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Top Header: User Info + Follow Option + 3 Dots
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToProfile(widget.post.authorId),
                    child: SafeAvatar(
                      avatarUrl: widget.post.authorPhoto,
                      username: widget.post.authorId,
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateToProfile(widget.post.authorId),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.post.authorDisplayName ?? "@${widget.post.authorId}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (widget.post.aiVerified)
                                const Icon(Icons.verified, color: Color(0xFF6C63FF), size: 14)
                              else
                                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                            ],
                          ),
                          Text(
                            "@${widget.post.authorId}",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Follow / Following Button (Global state synced via FollowButton)
                  if (_myUsername != null && _myUsername != widget.post.authorId) ...[
                    FollowButton(username: widget.post.authorId),
                    const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 4),

                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white70),
                    onPressed: _showMoreOptions,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildContent(),
            ),

            // Bottom Footer Actions: Like, Comment, Share, Repost, Save
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Like (Heart toggles, clicking count opens likers dialog)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _toggleLike,
                            child: Icon(
                              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _isLiked ? Colors.redAccent : Colors.white70,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _showLikersSheet,
                            child: Text(
                              "$_likesCount",
                              style: TextStyle(
                                color: _isLiked ? Colors.redAccent : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Comment
                      GestureDetector(
                        onTap: _showCommentsSheet,
                        child: _ActionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          color: Colors.white70,
                          label: "$_repliesCount",
                        ),
                      ),

                      // Share
                      GestureDetector(
                        onTap: _showShareSheet,
                        child: const _ActionButton(
                          icon: Icons.send_rounded,
                          color: Colors.white70,
                          label: "Share",
                        ),
                      ),

                      // Repost
                      GestureDetector(
                        onTap: _toggleRepost,
                        child: _ActionButton(
                          icon: Icons.repeat_rounded,
                          color: _isReposted ? Colors.greenAccent : Colors.white70,
                          label: _repostsCount > 0 ? "$_repostsCount" : "Repost",
                        ),
                      ),

                      // Save
                      GestureDetector(
                        onTap: _toggleSave,
                        child: Icon(
                          _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: _isSaved ? const Color(0xFF6C63FF) : Colors.white70,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.post.type) {
      case PostType.confession:
        return ConfessionPostWidget(post: widget.post);
      case PostType.poll:
        return PollPostWidget(post: widget.post);
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.post.content.isNotEmpty)
              Text(
                widget.post.content,
                style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
              ),
            if (widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: widget.post.mediaUrl!,
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 240,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _ActionButton({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// -------------------------------------------------------------
// Interactive Instagram-Style Comments Bottom Sheet
// -------------------------------------------------------------
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final ApiService apiService;
  final Function(int count) onCommentCountChanged;
  final Function(String username) onNavigateToProfile;

  const _CommentsSheet({
    required this.postId,
    required this.apiService,
    required this.onCommentCountChanged,
    required this.onNavigateToProfile,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  String? _replyToCommentId;
  String? _replyToUsername;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final res = await widget.apiService.get('/posts/${widget.postId}/comments');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _comments = list;
            _isLoading = false;
          });
          widget.onCommentCountChanged(_comments.length);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    _commentCtrl.clear();
    final parentId = _replyToCommentId;
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
    });

    try {
      final res = await widget.apiService.post('/posts/${widget.postId}/comments', {
        'content': text,
        if (parentId != null) 'parent_comment_id': parentId,
      });
      if (res.statusCode == 200) {
        _loadComments();
      }
    } catch (e) {
      debugPrint("Submit comment error: $e");
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final res = await widget.apiService.delete('/posts/comments/$commentId');
      if (res.statusCode == 200) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == commentId || c['_id'] == commentId);
        });
        widget.onCommentCountChanged(_comments.length);
      }
    } catch (e) {
      debugPrint("Delete comment error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Comments (${_comments.length})",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Divider(color: Colors.white10, height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          "No comments yet.\nStart the conversation!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (ctx, idx) {
                          final c = _comments[idx];
                          final cid = c['id']?.toString() ?? c['_id']?.toString() ?? '';
                          final username = c['author_username']?.toString() ?? 'User';
                          final photo = c['author_photo']?.toString();
                          final content = c['content']?.toString() ?? '';
                          final isOwn = c['is_own'] == true;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onNavigateToProfile(username);
                                  },
                                  child: SafeAvatar(
                                    avatarUrl: photo,
                                    username: username,
                                    radius: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                              widget.onNavigateToProfile(username);
                                            },
                                            child: Text(
                                              username,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "now",
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        content,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _replyToCommentId = cid;
                                                _replyToUsername = username;
                                              });
                                              _focusNode.requestFocus();
                                            },
                                            child: Text(
                                              "Reply",
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (isOwn) ...[
                                            const SizedBox(width: 16),
                                            GestureDetector(
                                              onTap: () => _deleteComment(cid),
                                              child: const Text(
                                                "Delete",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Replying banner
          if (_replyToUsername != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.white.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Text(
                    "Replying to @$_replyToUsername",
                    style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyToCommentId = null;
                      _replyToUsername = null;
                    }),
                    child: const Icon(Icons.close, size: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF141424),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _replyToUsername != null
                          ? "Reply to @$_replyToUsername..."
                          : "Add a comment...",
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF6C63FF)),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Interactive Instagram-Style Share to DM Bottom Sheet
// -------------------------------------------------------------
class _ShareSheet extends StatefulWidget {
  final String postId;
  final String postContent;
  final ApiService apiService;

  const _ShareSheet({
    required this.postId,
    required this.postContent,
    required this.apiService,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  final Set<String> _sentUsers = {};

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    try {
      final res = await widget.apiService.get('/chats');
      if (res.statusCode == 200) {
        final List chats = jsonDecode(res.body);
        final List<Map<String, dynamic>> friends = [];
        for (var c in chats) {
          final other = c['other_user']?.toString();
          if (other != null && other.isNotEmpty) {
            friends.add({
              'username': other,
              'display_name': c['other_display_name'] ?? other,
              'profile_photo_url': c['other_photo'],
            });
          }
        }
        if (mounted) {
          setState(() {
            _users = friends;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareWithUser(String username) async {
    if (_sentUsers.contains(username)) return;

    setState(() => _sentUsers.add(username));
    try {
      final res = await widget.apiService.post('/posts/${widget.postId}/share', {
        'recipient_username': username,
      });
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Post sent to @$username"),
            backgroundColor: const Color(0xFF1A1A2E),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Share error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Share Post",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          // Action row: Copy Link
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.link_rounded, size: 20),
                    label: const Text("Copy Link"),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: "https://zenvora.app/posts/${widget.postId}"));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Link copied to clipboard")),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          "No active chats found.\nStart a chat first to share posts directly!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (ctx, idx) {
                          final u = _users[idx];
                          final username = u['username'] ?? 'User';
                          final isSent = _sentUsers.contains(username);

                          return ListTile(
                            leading: SafeAvatar(
                              avatarUrl: u['profile_photo_url'],
                              username: username,
                              radius: 20,
                            ),
                            title: Text(
                              u['display_name'] ?? username,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "@$username",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSent ? Colors.white12 : const Color(0xFF6C63FF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: isSent ? null : () => _shareWithUser(username),
                              child: Text(
                                isSent ? "Sent" : "Send",
                                style: TextStyle(
                                  color: isSent ? Colors.white60 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
