import 'package:flutter/material.dart';
import '../models/post_model.dart';

class TrendingSection extends StatelessWidget {
  final List<PostModel> trendingPosts;
  const TrendingSection({super.key, required this.trendingPosts});

  @override
  Widget build(BuildContext context) {
    if (trendingPosts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.whatshot, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                "TRENDING NOW",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: trendingPosts.length,
            itemBuilder: (context, index) {
              final post = trendingPosts[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12, bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(
                            "https://api.dicebear.com/7.x/avataaars/svg?seed=${post.authorId}",
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "@${post.authorId}",
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                        post.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text("${post.likes}", style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        const Text("🔥 Trending", style: TextStyle(fontSize: 10, color: Colors.orange)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
