import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'confession_post.dart';
import 'poll_post.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      "https://api.dicebear.com/7.x/avataaars/svg?seed=${post.authorId}",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "@${post.authorId}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (post.aiVerified)
                            const Icon(Icons.verified, color: Color(0xFF6C63FF), size: 14)
                          else
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                        ],
                      ),
                      Text(
                        "2 hours ago",
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white54),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildContent(),
            ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ActionButton(icon: Icons.favorite_border, label: "${post.likes}"),
                      const SizedBox(width: 20),
                      _ActionButton(icon: Icons.chat_bubble_outline, label: "${post.repliesCount}"),
                      const SizedBox(width: 20),
                      _ActionButton(icon: Icons.repeat, label: "Share"),
                      const Spacer(),
                      _StartChatButton(onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (post.type) {
      case PostType.confession:
        return ConfessionPostWidget(post: post);
      case PostType.poll:
        return PollPostWidget(post: post);
      default:
        return Text(
          post.content,
          style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}

class _StartChatButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartChatButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          "Start Anonymous Chat",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
