import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:ui';
import '../../core/services/api_service.dart';
import '../chat/chat_screen.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'widgets/premium_profile_widgets.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;
  const UserProfileScreen({super.key, required this.username});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  final _apiService = ApiService();
  Map<String, dynamic>? _profile;
  List<dynamic> _userPosts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  late ScrollController _scrollController;
  late TabController _tabController;
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _tabController = TabController(length: 3, vsync: this);
    _fetchUserData();
  }

  void _onScroll() {
    if (!mounted) return;
    double offset = _scrollController.offset;
    double opacity = (offset / 150).clamp(0.0, 1.0);
    if (opacity != _appBarOpacity) {
      setState(() => _appBarOpacity = opacity);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await _apiService.get('/users/${widget.username}');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _profile = jsonDecode(response.body);
            _isFollowing = _profile?['is_following'] ?? false;
          });
        }
      }

      // Safe posts fetching: only if username is valid
      if (widget.username.isNotEmpty) {
        final postsResponse = await _apiService.get('/posts/feed');
        if (postsResponse.statusCode == 200) {
          final List allPosts = jsonDecode(postsResponse.body);
          if (mounted) {
            setState(() {
              _userPosts = allPosts.where((p) => p['author_username'] == widget.username).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startChat() async {
    try {
      final response = await _apiService.post('/chats/start/${widget.username}', {});
      if (response.statusCode == 200) {
        final chat = jsonDecode(response.body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chat['_id'], otherUser: widget.username),
            ),
          );
        }
      }
    } catch (e) {}
  }

  void _toggleFollow() async {
    try {
      final endpoint = _isFollowing ? '/social/unfollow/${widget.username}' : '/social/follow/${widget.username}';
      final response = await _apiService.post(endpoint, {});
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _isFollowing = !_isFollowing;
            if (_profile != null) {
              _profile?['followers_count'] = (_profile?['followers_count'] ?? 0) + (_isFollowing ? 1 : -1);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Toggle Follow Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF0F0F1A), body: ProfileSkeleton());
    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A), 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_rounded, color: Colors.white24, size: 60),
              const SizedBox(height: 16),
              const Text("User not found", style: TextStyle(color: Colors.white70)),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("GO BACK")),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
          SliverToBoxAdapter(child: _buildHeaderSection()),
          SliverToBoxAdapter(child: _buildStatsSection()),
          SliverToBoxAdapter(child: _buildActionSection()),
          SliverToBoxAdapter(child: _buildHighlightsSection()),
          _buildContentTabs(),
          _buildPostsGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * _appBarOpacity, sigmaY: 10 * _appBarOpacity),
          child: AppBar(
            backgroundColor: const Color(0xFF1A1A2E).withOpacity(_appBarOpacity * 0.8),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Opacity(
              opacity: _appBarOpacity,
              child: Text(
                widget.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Hero(
            tag: 'avatar_${widget.username}',
            child: PremiumAvatar(
              imageUrl: _profile?['avatar_url']?.toString(),
              radius: 60,
              isOnline: true,
              isSpeaking: false,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _profile?['display_name']?.toString() ?? widget.username,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            "@${widget.username}",
            style: const TextStyle(fontSize: 14, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            _profile?['bio']?.toString() ?? "No bio available.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildTag("${_profile?['age'] ?? '??'} yo"),
              _buildTag(_profile?['country']?.toString() ?? "Earth"),
              _buildTag(_profile?['personality_type']?.toString() ?? "User"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PremiumStatItem(label: "Posts", value: _userPosts.length.toString()),
          PremiumStatItem(
            label: "Followers", 
            value: _profile?['followers_count']?.toString() ?? "0",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersScreen(username: widget.username))),
          ),
          PremiumStatItem(
            label: "Following", 
            value: _profile?['following_count']?.toString() ?? "0",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowingScreen(username: widget.username))),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GlassButton(
              label: _isFollowing ? "Following" : "Follow",
              isPrimary: !_isFollowing,
              onTap: _toggleFollow,
            ),
          ),
          const SizedBox(width: 12),
          GlassButton(
            label: "Message",
            onTap: _startChat,
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "HIGHLIGHTS",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            children: const [
              StoryCircle(title: "Featured", imageUrl: "https://picsum.photos/200/300?random=31"),
              StoryCircle(title: "Life", imageUrl: "https://picsum.photos/200/300?random=32"),
              StoryCircle(title: "Voice", imageUrl: "https://picsum.photos/200/300?random=33"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        child: Container(
          color: const Color(0xFF0F0F1A),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.grid_view_rounded)),
              Tab(icon: Icon(Icons.video_collection_rounded)),
              Tab(icon: Icon(Icons.bookmark_outline_rounded)),
            ],
            indicatorColor: const Color(0xFF6C63FF),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            unselectedLabelColor: Colors.white24,
            labelColor: const Color(0xFF6C63FF),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsGrid() {
    if (_userPosts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: Colors.white10),
              SizedBox(height: 16),
              Text("No posts yet", style: TextStyle(color: Colors.white24)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = _userPosts[index];
            final mediaUrl = post['media_url']?.toString();
            return GestureDetector(
              onTap: () {},
              child: Container(
                color: const Color(0xFF1A1A2E),
                child: (mediaUrl != null && mediaUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white10),
                      )
                    : const Center(child: Icon(Icons.text_snippet, color: Colors.white10)),
              ),
            );
          },
          childCount: _userPosts.length,
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverAppBarDelegate({required this.child});
  @override
  double get minExtent => 50.0;
  @override
  double get maxExtent => 50.0;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
