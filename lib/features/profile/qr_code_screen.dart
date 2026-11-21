import 'package:flutter/material.dart';
import '../../widgets/safe_avatar.dart';

class QrCodeScreen extends StatelessWidget {
  final Map<String, dynamic> profile;

  const QrCodeScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final username = profile['username'] ?? profile['anonymous_username'] ?? 'User';
    final photo = profile['profile_photo_url'] ?? profile['avatar_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Profile QR Code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeAvatar(avatarUrl: photo, username: username, radius: 40),
              const SizedBox(height: 12),
              Text("@$username", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.qr_code_2_rounded, size: 160, color: Color(0xFF0F0F1A)),
              ),
              const SizedBox(height: 24),
              const Text("Scan to open profile on Zenvora", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
