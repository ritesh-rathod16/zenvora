import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import '../profile/user_profile_screen.dart';
import '../feed/models/post_model.dart';
import '../feed/widgets/post_card.dart';

class SearchPeopleScreen extends StatefulWidget {
  const SearchPeopleScreen({super.key});

  @override
  State<SearchPeopleScreen> createState() => _SearchPeopleScreenState();
}

class _SearchPeopleScreenState extends State<SearchPeopleScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  List<dynamic> _userResults = [];
  List<PostModel> _explorePosts = [];
  bool _isSearching = false;
  bool _isLoadingExplore = true;

  @override
  void initState() {
    super.initState();
    _fetchExploreGrid();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExploreGrid() async {
    try {
      final response = await _apiService.get('/posts/feed');
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<PostModel> fetched = data.map((j) => PostModel.fromJson(j)).toList();
        setState(() {
          _explorePosts = fetched;
          _isLoadingExplore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingExplore = false);
    }
  }

  void _onSearchChanged(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _userResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final response = await _apiService.get('/users/search?q=$cleanQuery');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _userResults = jsonDecode(response.body);
        });
      }
    } catch (_) {
      debugPrint("People search failed.");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            // Instagram-style Search Bar
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search users, interests...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6C63FF)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged("");
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (_isSearching)
              const LinearProgressIndicator(color: Color(0xFF6C63FF), backgroundColor: Colors.transparent),

            // Content Area: Search Results or Instagram Explore Grid
            Expanded(
              child: _searchController.text.trim().isNotEmpty
                  ? _buildSearchResults()
                  : _buildExploreGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_userResults.isEmpty && !_isSearching) {
      return const Center(
        child: Text("No users found.", style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        final username = user['username'] ?? 'User';
        final avatar = user['avatar_url'] ?? user['profile_photo_url'] ?? "https://api.dicebear.com/7.x/avataaars/png?seed=$username";

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: SafeAvatar(
              avatarUrl: user['avatar_url'] ?? user['profile_photo_url'],
              username: username,
              radius: 22,
            ),
            title: Text("@$username", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
            subtitle: Text("Trust Score: ${user['trust_score'] ?? 100}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
            onTap: () => _openProfile(username),
          ),
        );
      },
    );
  }

  Widget _buildExploreGrid() {
    if (_isLoadingExplore) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }

    final imagePosts = _explorePosts.where((p) => p.mediaUrl != null && p.mediaUrl!.isNotEmpty).toList();

    if (imagePosts.isEmpty) {
      return const Center(
        child: Text("Explore community posts", style: TextStyle(color: Colors.white38)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: imagePosts.length,
      itemBuilder: (context, index) {
        final post = imagePosts[index];
        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF0F0F1A),
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: PostCard(post: post),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: post.mediaUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.05)),
                errorWidget: (context, url, error) => Container(color: const Color(0xFF1A1A2E)),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 10, color: Colors.redAccent),
                      const SizedBox(width: 3),
                      Text("${post.likes}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
