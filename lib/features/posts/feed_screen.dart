import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import '../feed/models/post_model.dart';
import '../feed/widgets/post_card.dart';
import '../feed/widgets/story_section.dart';
import '../feed/widgets/trending_section.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _apiService = ApiService();
  List<PostModel> _posts = [];
  List<PostModel> _trendingPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    try {
      final response = await _apiService.get('/posts/feed');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<PostModel> fetchedPosts = data.map((json) => PostModel.fromJson(json)).toList();
        
        setState(() {
          _posts = fetchedPosts;
          _trendingPosts = fetchedPosts.where((p) => p.isTrending).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF6C63FF),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
      body: _isLoading 
          ? const _FeedSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchFeed,
              color: const Color(0xFF6C63FF),
              backgroundColor: const Color(0xFF1A1A2E),
              child: CustomScrollView(
                slivers: [
                  // App Bar / Stories
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12.0),
                      child: StorySection(),
                    ),
                  ),

                  // Trending Section
                  SliverToBoxAdapter(
                    child: TrendingSection(trendingPosts: _trendingPosts),
                  ),

                  // Main Feed Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        "DISCOVER THOUGHTS",
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),

                  // Feed Posts
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _AnimatedPostCard(
                          post: _posts[index],
                          index: index,
                        );
                      },
                      childCount: _posts.length,
                    ),
                  ),
                  
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
    );
  }
}

class _AnimatedPostCard extends StatefulWidget {
  final PostModel post;
  final int index;
  const _AnimatedPostCard({required this.post, required this.index});

  @override
  State<_AnimatedPostCard> createState() => _AnimatedPostCardState();
}

class _AnimatedPostCardState extends State<_AnimatedPostCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + (widget.index * 100).clamp(0, 600)),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: PostCard(post: widget.post),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
