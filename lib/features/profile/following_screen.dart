import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:shimmer/shimmer.dart';
import '../../core/services/api_service.dart';
import 'user_profile_screen.dart';
import 'widgets/premium_profile_widgets.dart';

class FollowingScreen extends StatefulWidget {
  final String username;
  const FollowingScreen({super.key, required this.username});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchFollowing();
  }

  Future<void> _fetchFollowing() async {
    try {
      final response = await _apiService.get('/users/${widget.username}/following');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _users = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unfollowUser(String targetUsername) async {
    try {
      final response = await _apiService.post('/social/unfollow/$targetUsername', {});
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _users.removeWhere((u) => u['username']?.toString() == targetUsername);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1A1A2E),
              content: Text("Unfollowed @$targetUsername", style: const TextStyle(color: Colors.white70)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Unfollow Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      final uname = u['username']?.toString().toLowerCase() ?? "";
      return uname.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "FOLLOWING",
          style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? _buildSkeletonList()
                : RefreshIndicator(
                    onRefresh: _fetchFollowing,
                    color: const Color(0xFF6C63FF),
                    child: filteredUsers.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) => _buildUserTile(filteredUsers[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white.withOpacity(0.05),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search following...",
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                icon: Icon(Icons.search_rounded, color: Colors.white24, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(dynamic user) {
    final username = user['username']?.toString() ?? "Stranger";
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(username: username))),
            child: PremiumAvatar(
              imageUrl: user['avatar_url']?.toString(),
              radius: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(username: username))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "@$username",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    "Friend since 3 months",
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.white30),
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _unfollowUser(username),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white70,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text("Following", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: const Color(0xFF1A1A2E),
        highlightColor: const Color(0xFF252545),
        child: Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Icon(Icons.person_search_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Center(child: Text("You aren't following anyone", style: GoogleFonts.poppins(color: Colors.white24))),
        ],
      ),
    );
  }
}
