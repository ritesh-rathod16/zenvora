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
import 'saved_screen.dart';
import 'qr_code_screen.dart';
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
  List<dynamic> _userReels = [];
  List<dynamic> _userReposts = [];
  List<dynamic> _userHighlights = [];
  bool _isLoading = true;
  late ScrollController _scrollController;
  late TabController _tabController;
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _tabController = TabController(length: 4, vsync: this);
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
        await _fetchHighlights();
      }
    } catch (_) {
      debugPrint("Profile data loading failed.");
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
    } catch (_) {
      debugPrint("Profile request failed.");
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

      final reelsRes = await _apiService.get('/reels/saved');
      if (reelsRes.statusCode == 200 && mounted) {
        setState(() {
          _userReels = jsonDecode(reelsRes.body);
        });
      }

      final repostsRes = await _apiService.get('/posts/user/$username/reposts');
      if (repostsRes.statusCode == 200 && mounted) {
        setState(() {
          _userReposts = jsonDecode(repostsRes.body);
        });
      }
    } catch (_) {
      debugPrint("Profile posts loading failed.");
    }
  }

  Future<void> _fetchHighlights() async {
    try {
      final username = _profile?['username'] ?? _profile?['anonymous_username'];
      if (username == null) return;

      final res = await _apiService.get('/highlights/$username');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _userHighlights = jsonDecode(res.body);
        });
      }
    } catch (_) {}
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

  void _openEditProfile() async {
    if (_profile == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile!),
      ),
    );

    if (updated == true) {
      _loadProfileData();
    }
  }

  void _showProfileOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white),
              title: const Text("Settings & Privacy", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(profile: _profile)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline_rounded, color: Colors.white),
              title: const Text("Saved Collections", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded, color: Colors.white),
              title: const Text("Profile QR Code", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                if (_profile != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => QrCodeScreen(profile: _profile!)));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                const storage = FlutterSecureStorage();
                await storage.deleteAll();
                if (mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: ProfileSkeleton(),
      );
    }

    final String username = _profile?['username'] ?? _profile?['anonymous_username'] ?? 'User';
    final String displayName = _profile?['full_name'] ?? _profile?['display_name'] ?? username;
    final String? photoUrl = _profile?['profile_photo_url'] ?? _profile?['avatar_url'];
    final String bio = _profile?['bio'] ?? '';
    final String? website = _profile?['website'];

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
              centerTitle: true,
              title: Opacity(
                opacity: _appBarOpacity,
                child: Text(
                  "@$username",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onPressed: _showProfileOptionsMenu,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        color: const Color(0xFF6C63FF),
        backgroundColor: const Color(0xFF1A1A2E),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverToBoxAdapter(
              child: _buildHeaderSection(username, displayName, photoUrl, bio, website),
            ),
            SliverToBoxAdapter(
              child: _buildStatsSection(username),
            ),
            SliverToBoxAdapter(child: _buildActionSection()),
            SliverToBoxAdapter(child: _buildHighlightsSection()),
            _buildContentTabs(),
            _buildSelectedTabGrid(),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(String username, String displayName, String? photoUrl, String bio, String? website) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadProfilePhoto,
            child: Stack(
              children: [
                SafeAvatar(
                  avatarUrl: photoUrl,
                  username: username,
                  radius: 55,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
        ],
      ),
    );
  }

  Widget _buildStatsSection(String username) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
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
                if (_profile != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => QrCodeScreen(profile: _profile!)));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection() {
    return SizedBox(
      height: 90,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          ..._userHighlights.map((h) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6C63FF), width: 1.5)),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF1A1A2E),
                    backgroundImage: h['cover_url'] != null ? CachedNetworkImageProvider(h['cover_url']) : null,
                    child: h['cover_url'] == null ? const Icon(Icons.star_rounded, color: Colors.amberAccent) : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(h['title'] ?? 'Highlight', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          )),
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
              Tab(icon: Icon(Icons.video_collection_rounded), text: "Reels"),
              Tab(icon: Icon(Icons.repeat_rounded), text: "Reposts"),
              Tab(icon: Icon(Icons.person_pin_rounded), text: "Tagged"),
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

  Widget _buildSelectedTabGrid() {
    List<dynamic> activeList = [];
    if (_tabController.index == 0) activeList = _userPosts;
    if (_tabController.index == 1) activeList = _userReels;
    if (_tabController.index == 2) activeList = _userReposts;

    if (activeList.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(
            child: Text("No content here yet", style: TextStyle(color: Colors.white38)),
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
            final item = activeList[index];
            final String? mediaUrl = item['media_url'] ?? item['video_url'];

            return Container(
              color: const Color(0xFF1A1A2E),
              child: mediaUrl != null && mediaUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          item['content'] ?? item['caption'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ),
            );
          },
          childCount: activeList.length,
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _SliverAppBarDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
