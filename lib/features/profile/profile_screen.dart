import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/api_service.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'widgets/premium_profile_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _apiService = ApiService();
  Map<String, dynamic>? _profile;
  List<dynamic> _userPosts = [];
  bool _isLoading = true;
  late ScrollController _scrollController;
  late TabController _tabController;
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
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

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Step 1: Fetch Profile First
      await _fetchProfile();
      
      // Step 2: Fetch Posts if profile succeeded
      if (_profile != null) {
        await _fetchUserPosts();
      }
    } catch (e) {
      debugPrint("Error loading profile data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await _apiService.get('/users/me');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _profile = decoded;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Profile Error: $e");
    }
  }

  Future<void> _fetchUserPosts() async {
    try {
      final response = await _apiService.get('/posts/feed');
      if (response.statusCode == 200) {
        final List posts = jsonDecode(response.body);
        final currentUsername = _profile?['anonymous_username'];
        
        if (mounted && currentUsername != null) {
          setState(() {
            _userPosts = posts.where((p) => p['author_id'] == currentUsername).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch User Posts Error: $e");
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      try {
        final response = await _apiService.uploadFile('/users/upload-profile-photo', image.path);
        if (response.statusCode == 200) {
          _fetchProfile();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
      }
    }
  }

  Future<void> _logout() async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A), 
        body: ProfileSkeleton(),
      );
    }
    
    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A), 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white24, size: 60),
              const SizedBox(height: 16),
              const Text("Profile terminal unavailable", style: TextStyle(color: Colors.white70)),
              TextButton(onPressed: _loadProfileData, child: const Text("RECONNECT")),
            ],
          ),
        ),
      );
    }

    final bool isAdmin = _profile?['role'] == 'admin' || _profile?['role'] == 'super_admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isAdmin),
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
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isAdmin) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * _appBarOpacity, sigmaY: 10 * _appBarOpacity),
          child: AppBar(
            backgroundColor: const Color(0xFF1A1A2E).withOpacity(_appBarOpacity * 0.8),
            elevation: 0,
            title: Opacity(
              opacity: _appBarOpacity,
              child: Text(
                (_profile?['anonymous_username'] ?? "GHOST").toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            centerTitle: true,
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF6C63FF)),
                  onPressed: () => context.push('/admin'),
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
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
          PremiumAvatar(
            imageUrl: _profile?['avatar_url']?.toString(),
            radius: 60,
            isOnline: true,
            onTap: _uploadProfilePhoto,
          ),
          const SizedBox(height: 20),
          Text(
            _profile?['real_name']?.toString() ?? _profile?['anonymous_username']?.toString() ?? "Ghost User",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            "@${_profile?['anonymous_username']?.toString() ?? 'unknown'}",
            style: const TextStyle(fontSize: 14, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            _profile?['bio']?.toString() ?? "Exploring the digital void. ✨",
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
              _buildTag(_profile?['personality_type']?.toString() ?? "Explorer"),
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
            onTap: () {
              final username = _profile?['anonymous_username'];
              if (username != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersScreen(username: username.toString())));
              }
            },
          ),
          PremiumStatItem(
            label: "Following", 
            value: _profile?['following_count']?.toString() ?? "0",
            onTap: () {
              final username = _profile?['anonymous_username'];
              if (username != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FollowingScreen(username: username.toString())));
              }
            },
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
              label: "Edit Profile",
              isPrimary: true,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassButton(
              label: "Logout",
              onTap: _logout,
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
              StoryCircle(title: "Moments", imageUrl: "https://picsum.photos/200/300?random=21"),
              StoryCircle(title: "Life", imageUrl: "https://picsum.photos/200/300?random=22"),
              StoryCircle(title: "Vibes", imageUrl: "https://picsum.photos/200/300?random=23"),
              StoryCircle(title: "New"),
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
              Tab(icon: Icon(Icons.person_pin_outlined)),
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
      return SliverFillRemaining(
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white10),
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
            return Container(
              color: const Color(0xFF1A1A2E),
              child: (mediaUrl != null && mediaUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white10),
                    )
                  : const Center(child: Icon(Icons.text_snippet, color: Colors.white10)),
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
