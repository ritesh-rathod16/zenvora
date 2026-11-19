import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/api_service.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  final List<dynamic> _savedPosts = [];
  List<dynamic> _savedReels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSavedContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSavedContent() async {
    try {
      final res = await _apiService.get('/reels/saved');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _savedReels = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Saved Collections", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Saved Posts"),
            Tab(text: "Saved Reels"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                // Saved Posts Tab
                _savedPosts.isEmpty
                    ? const Center(child: Text("No saved posts yet", style: TextStyle(color: Colors.white38)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _savedPosts.length,
                        itemBuilder: (context, index) {
                          final p = _savedPosts[index];
                          return CachedNetworkImage(
                            imageUrl: p['media_url'] ?? '',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.white10),
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24),
                          );
                        },
                      ),

                // Saved Reels Tab
                _savedReels.isEmpty
                    ? const Center(child: Text("No saved reels yet", style: TextStyle(color: Colors.white38)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _savedReels.length,
                        itemBuilder: (context, index) {
                          final r = _savedReels[index];
                          return Container(
                            color: const Color(0xFF1A1A2E),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white54, size: 36)),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Text(
                                    "@${r['author_id'] ?? ''}",
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}
