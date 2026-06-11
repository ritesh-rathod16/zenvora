import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import 'dart:convert';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _apiService = ApiService();
  Map<String, dynamic> _settings = {
    'registrations_enabled': true,
    'posting_enabled': true,
    'video_chat_enabled': true,
    'image_uploads_enabled': true,
    'maintenance_mode': false,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await _apiService.get('/admin/settings');
      if (response.statusCode == 200) {
        setState(() {
          _settings = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _updateSetting(String key, bool value) async {
    try {
      final response = await _apiService.patch('/admin/settings', {key: value});
      if (response.statusCode == 200) {
        setState(() {
          _settings[key] = value;
        });
      }
    } catch (e) {}
  }

  Future<void> _logout(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'token');
    await storage.delete(key: 'user');
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                const Text("FEATURE FLAGS", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                _buildToggleCard("Registrations", "Allow new users to sign up", 'registrations_enabled', Icons.person_add),
                _buildToggleCard("Anonymous Posting", "Allow users to create new posts", 'posting_enabled', Icons.post_add),
                _buildToggleCard("Video Chat", "Enable random video matchmaking", 'video_chat_enabled', Icons.videocam),
                _buildToggleCard("Image Uploads", "Allow users to upload photos", 'image_uploads_enabled', Icons.image),
                const SizedBox(height: 32),
                const Text("SYSTEM", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                _buildToggleCard("Maintenance Mode", "Lock the platform", 'maintenance_mode', Icons.build, isWarning: true),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text("EXIT ADMIN HQ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildToggleCard(String title, String subtitle, String key, IconData icon, {bool isWarning = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: isWarning ? Colors.redAccent : const Color(0xFF6C63FF)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isWarning ? Colors.redAccent : Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        value: _settings[key] ?? false,
        activeColor: const Color(0xFF6C63FF),
        onChanged: (v) => _updateSetting(key, v),
      ),
    );
  }
}
