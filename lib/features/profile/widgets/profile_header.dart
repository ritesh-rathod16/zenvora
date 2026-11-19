import 'package:flutter/material.dart';
import '../../../widgets/safe_avatar.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String fullName;
  final String? profilePhotoUrl;
  final String bio;
  final String? website;
  final int? age;
  final String? country;
  final List<dynamic> interests;
  final bool isPrivate;
  final Map<String, dynamic> visibilitySettings;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.fullName,
    this.profilePhotoUrl,
    required this.bio,
    this.website,
    this.age,
    this.country,
    required this.interests,
    required this.isPrivate,
    required this.visibilitySettings,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final showAge = visibilitySettings['show_age'] ?? true;
    final showCountry = visibilitySettings['show_country'] ?? true;
    final showInterests = visibilitySettings['show_interests'] ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: SafeAvatar(
              avatarUrl: profilePhotoUrl,
              username: username,
              radius: 55,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                fullName.isNotEmpty ? fullName : username,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (isPrivate) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 16),
              ],
            ],
          ),
          Text(
            "@$username",
            style: const TextStyle(fontSize: 14, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
            ),
          ],
          if (website != null && website!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF00F0FF), size: 14),
                const SizedBox(width: 4),
                Text(
                  website!,
                  style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (showAge && age != null) _buildTag("$age yo"),
              if (showCountry && country != null && country!.isNotEmpty) _buildTag(country!),
              if (showInterests && interests.isNotEmpty) ...interests.take(3).map((i) => _buildTag(i.toString())),
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
}
