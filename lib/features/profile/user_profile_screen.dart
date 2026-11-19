import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:ui';
import '../../core/services/api_service.dart';
import '../../widgets/safe_avatar.dart';
import '../../widgets/follow_button.dart';
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
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profile;
  List<dynamic> _userPosts = [];
  List<dynamic> _userReposts = [];
  bool _isLoadingProfile = true;
  bool _isLoadingContent = true;
  late ScrollController _scrollController;
  late TabController _tabController;
  double _appBarOpacity = 0.0;

  String get _cleanUsername => widget.username.replaceAll('@', '').trim();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchProfileData();
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

  Future<void> _fetchProfileData() async {
    if (_cleanUsername.isEmpty) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      // 1. Fetch user profile header immediately
      final response = await _apiService.get('/users/$_cleanUsername');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _profile = data;
          _isLoadingProfile = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }

      // 2. Load posts & reposts asynchronously
      _fetchUserPostsAndReposts();
    } catch (e) {
      debugPrint("Error fetching profile for $_cleanUsername: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _fetchUserPostsAndReposts() async {
    try {
      final postsRes = await _apiService.get('/posts/user/$_cleanUsername');
      if (postsRes.statusCode == 200 && mounted) {
        setState(() {
          _userPosts = jsonDecode(postsRes.body);
        });
      }

      final repostsRes = await _apiService.get('/posts/user/$_cleanUsername/reposts');
      if (repostsRes.statusCode == 200 && mounted) {
        setState(() {
          _userReposts = jsonDecode(repostsRes.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching posts for $_cleanUsername: $e");
    } finally {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

  void _startChat() async {
    try {
      final response = await _apiService.post('/chats/start/$_cleanUsername', {});
      if (response.statusCode == 200) {
        final chat = jsonDecode(response.body);
        final chatId = chat['_id'] ?? chat['id'];
        if (mounted && chatId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chatId, otherUser: _cleanUsername),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Start Chat Error: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: ProfileSkeleton(),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_rounded, color: Colors.white24, size: 60),
              const SizedBox(height: 16),
              Text("User '@$_cleanUsername' not found", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProfileData,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                child: const Text("RETRY"),
              ),
            ],
          ),
        ),
      );
    }

    final String username = _profile?['username'] ?? _cleanUsername;
    final String displayName = _profile?['display_name'] ?? username;
    final String? photoUrl = _profile?['profile_photo_url'] ?? _profile?['avatar_url'];
    final String bio = _profile?['bio'] ?? '';
    final String? website = _profile?['website'];
    final int followersCount = _profile?['followers_count'] ?? 0;
    final int followingCount = _profile?['following_count'] ?? 0;
    final int postsCount = _profile?['posts_count'] ?? _userPosts.length;
    final bool isPrivate = _profile?['is_private'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10 * _appBarOpacity, sigmaY: 10 * _appBarOpacity),
            child: AppBar(
              backgroundColor: const Color(0xFF1A1A2E).withValues(alpha: _appBarOpacity * 0.8),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              centerTitle: true,
              title: Opacity(
                opacity: _appBarOpacity,
                child: Text(
                  "@$username",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
          SliverToBoxAdapter(
            child: _buildHeaderSection(username, displayName, photoUrl, bio, website, isPrivate),
          ),
          SliverToBoxAdapter(
            child: _buildStatsSection(username, followersCount, followingCount, postsCount),
          ),
          SliverToBoxAdapter(child: _buildActionSection()),
          _buildContentTabs(),
          _buildPostsGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
    String username,
    String displayName,
    String? photoUrl,
    String bio,
    String? website,
    bool isPrivate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SafeAvatar(
            avatarUrl: photoUrl,
            username: username,
            radius: 55,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (isPrivate) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 16),
              ],
            ],
          ),
          Text(
            "@$username",
            style: const TextStyle(fontSize: 14, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
            ),
          ],
          if (website != null && website.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF00F0FF), size: 14),
                const SizedBox(width: 4),
                Text(
                  website,
                  style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildTag("${_profile?['age'] ?? '??'} yo"),
              _buildTag(_profile?['country']?.toString() ?? "Earth"),
              _buildTag(_profile?['personality_type']?.toString() ?? "Creator"),
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

  Widget _buildStatsSection(String username, int followersCount, int followingCount, int postsCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PremiumStatItem(label: "Posts", value: postsCount.toString()),
          PremiumStatItem(
            label: "Followers",
            value: followersCount.toString(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersScreen(username: username)));
            },
          ),
          PremiumStatItem(
            label: "Following",
            value: followingCount.toString(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowingScreen(username: username)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final String username = _profile?['username'] ?? _cleanUsername;
    final bool isPrivate = _profile?['is_private'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: FollowButton(
              username: username,
              isPrivate: isPrivate,
              onFollowChanged: _fetchProfileData,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassButton(
              label: "Message",
              icon: Icons.chat_bubble_outline_rounded,
              onTap: _startChat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        height: 48.0,
        child: Container(
          color: const Color(0xFF0F0F1A),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.grid_view_rounded), text: "Posts"),
              Tab(icon: Icon(Icons.repeat_rounded), text: "Reposts"),
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
    final bool isPostsTab = _tabController.index == 0;
    final List list = isPostsTab ? _userPosts : _userReposts;

    if (_isLoadingContent) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
        ),
      );
    }

    if (list.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isPostsTab ? Icons.photo_library_outlined : Icons.repeat_rounded, size: 48, color: Colors.white10),
              const SizedBox(height: 12),
              Text(isPostsTab ? "No posts yet" : "No reposts yet", style: const TextStyle(color: Colors.white24)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = list[index];
            final mediaUrl = item['media_url']?.toString();
            return Container(
              color: const Color(0xFF1A1A2E),
              child: (mediaUrl != null && mediaUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white10),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          item['content']?.toString() ?? '',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
            );
          },
          childCount: list.length,
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _SliverAppBarDelegate({required this.child, this.height = 48.0});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
