import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/api_service.dart';
import '../../widgets/safe_avatar.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'settings_screen.dart';
import 'screens/edit_profile_screen.dart';
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
  List<dynamic> _userReposts = [];
  bool _isLoading = true;
  late ScrollController _scrollController;
  late TabController _tabController;
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _tabController = TabController(length: 2, vsync: this);
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
      await _fetchProfile();
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
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _profile = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Fetch Profile Error: $e");
    }
  }

  Future<void> _fetchUserPosts() async {
    try {
      final username = _profile?['username'] ?? _profile?['anonymous_username'];
      if (username == null) return;

      final postsRes = await _apiService.get('/posts/user/$username');
      if (postsRes.statusCode == 200 && mounted) {
        setState(() {
          _userPosts = jsonDecode(postsRes.body);
        });
      }

      final repostsRes = await _apiService.get('/posts/user/$username/reposts');
      if (repostsRes.statusCode == 200 && mounted) {
        setState(() {
          _userReposts = jsonDecode(repostsRes.body);
        });
      }
    } catch (e) {
      debugPrint("Fetch User Posts/Reposts Error: $e");
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
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

  void _openEditProfile() {
    if (_profile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile!),
      ),
    ).then((updated) {
      if (updated == true) _loadProfileData();
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(profile: _profile),
      ),
    ).then((_) => _loadProfileData());
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
              const Icon(Icons.person_off_rounded, color: Colors.white24, size: 60),
              const SizedBox(height: 16),
              const Text("Profile unavailable", style: TextStyle(color: Colors.white70)),
              TextButton(onPressed: _loadProfileData, child: const Text("RECONNECT")),
            ],
          ),
        ),
      );
    }

    final String username = _profile?['username'] ?? _profile?['anonymous_username'] ?? 'User';
    final String? photoUrl = _profile?['profile_photo_url'] ?? _profile?['avatar_url'];

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
              title: Opacity(
                opacity: _appBarOpacity,
                child: Text(
                  "@$username",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: "Settings",
                  onPressed: _openSettings,
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
          SliverToBoxAdapter(child: _buildHeaderSection(username, photoUrl)),
          SliverToBoxAdapter(child: _buildStatsSection(username)),
          SliverToBoxAdapter(child: _buildActionSection()),
          _buildContentTabs(),
          _buildPostsGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(String username, String? photoUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadProfilePhoto,
            child: SafeAvatar(
              avatarUrl: photoUrl,
              username: username,
              radius: 60,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _profile?['display_name'] ?? username,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            "@$username",
            style: const TextStyle(fontSize: 14, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            _profile?['bio'] ?? "Exploring the digital space. ✨",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatsSection(String username) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PremiumStatItem(label: "Posts", value: _userPosts.length.toString()),
          PremiumStatItem(
            label: "Followers", 
            value: _profile?['followers_count']?.toString() ?? "0",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersScreen(username: username)));
            },
          ),
          PremiumStatItem(
            label: "Following", 
            value: _profile?['following_count']?.toString() ?? "0",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowingScreen(username: username)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GlassButton(
              label: "Edit Profile",
              isPrimary: true,
              onTap: _openEditProfile,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassButton(
              label: "Share Profile",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Profile link copied to clipboard!")),
                );
              },
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

    if (list.isEmpty) {
      return SliverFillRemaining(
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
                      placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.05)),
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
