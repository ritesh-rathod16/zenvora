import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/social_provider.dart';

class FollowButton extends StatelessWidget {
  final String username;
  final bool isPrivate;
  final VoidCallback? onFollowChanged;

  const FollowButton({
    super.key,
    required this.username,
    this.isPrivate = false,
    this.onFollowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialProvider>(
      builder: (context, socialProvider, child) {
        final isFollowing = socialProvider.isFollowing(username);
        final isPending = socialProvider.isPending(username);

        if (isFollowing) {
          return OutlinedButton(
            onPressed: () async {
              final ok = await socialProvider.unfollowUser(username);
              if (ok && onFollowChanged != null) onFollowChanged!();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
              backgroundColor: Colors.white.withOpacity(0.05),
              minimumSize: const Size(80, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Following",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          );
        }

        if (isPending) {
          return OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.amber.withOpacity(0.4)),
              backgroundColor: Colors.amber.withOpacity(0.05),
              minimumSize: const Size(80, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "Requested",
              style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          );
        }

        return ElevatedButton(
          onPressed: () async {
            final ok = await socialProvider.followUser(username, isPrivate: isPrivate);
            if (ok && onFollowChanged != null) onFollowChanged!();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            "Follow",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
