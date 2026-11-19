import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import 'story_settings_screen.dart';
import 'chat_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const SettingsScreen({super.key, this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiService = ApiService();
  bool _isPrivate = false;
  bool _notifLikes = true;
  bool _notifComments = true;
  bool _notifFollows = true;
  bool _notifMessages = true;
  bool _notifStories = true;
  String _theme = "dark";
  bool _isLoading = true;

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  String _selectedGender = "female";

  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final res = await _apiService.get('/users/me/settings');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _isPrivate = data['is_private'] ?? false;
          _theme = data['theme_preference'] ?? "dark";
          final notifs = data['notifications_enabled'] ?? {};
          _notifLikes = notifs['likes'] ?? true;
          _notifComments = notifs['comments'] ?? true;
          _notifFollows = notifs['follows'] ?? true;
          _notifMessages = notifs['messages'] ?? true;
          _notifStories = notifs['stories'] ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }

    if (widget.profile != null) {
      _displayNameController.text = widget.profile?['display_name'] ?? widget.profile?['username'] ?? '';
      _bioController.text = widget.profile?['bio'] ?? '';
      _websiteController.text = widget.profile?['website'] ?? '';
      _selectedGender = widget.profile?['gender'] ?? 'female';
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _apiService.patch('/users/me/settings', {
        'is_private': _isPrivate,
        'theme_preference': _theme,
        'notifications_enabled': {
          'likes': _notifLikes,
          'comments': _notifComments,
          'follows': _notifFollows,
          'messages': _notifMessages,
          'stories': _notifStories,
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating settings: $e")),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    try {
      final res = await _apiService.patch('/users/me/profile', {
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'website': _websiteController.text.trim(),
        'gender': _selectedGender,
      });
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile info updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e")),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPassController.text.isEmpty || _newPassController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter current password & new password (min 6 chars)")),
      );
      return;
    }

    try {
      final res = await _apiService.post('/users/me/change-password', {
        'current_password': _currentPassController.text.trim(),
        'new_password': _newPassController.text.trim(),
      });
      if (res.statusCode == 200 && mounted) {
        _currentPassController.clear();
        _newPassController.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password changed successfully!")),
        );
      } else {
        final err = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['detail'] ?? "Password change failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to log out of Zenvora?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
      context.go('/login');
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Change Password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPassController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Current Password"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "New Password (min 6 chars)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text("Update Password"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Settings & Privacy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // 1. Edit Profile Section
                _buildSectionHeader("EDIT PROFILE"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        TextField(
                          controller: _displayNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: "Display Name"),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bioController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: "Bio"),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _websiteController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: "Website"),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: ["female", "male", "other"].contains(_selectedGender) ? _selectedGender : "female",
                          dropdownColor: const Color(0xFF1A1A2E),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: "Gender (For Discover Category)"),
                          items: const [
                            DropdownMenuItem(value: "female", child: Text("Female (Girls)")),
                            DropdownMenuItem(value: "male", child: Text("Male (Boys)")),
                            DropdownMenuItem(value: "other", child: Text("Other / Non-binary")),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedGender = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          child: const Text("Save Profile Changes"),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Privacy & Account
                _buildSectionHeader("PRIVACY & SECURITY"),
                ListTile(
                  leading: const Icon(Icons.auto_stories_rounded, color: Colors.greenAccent),
                  title: const Text("Story Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Close Friends, Hide Story From, Replies, Reactions", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StorySettingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00F0FF)),
                  title: const Text("Messages & Chats", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Message controls, Receipts, Group Adds", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatSettingsScreen()),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text("Private Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Only approved followers can see your posts and stories.", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  value: _isPrivate,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (v) {
                    setState(() => _isPrivate = v);
                    _saveSettings();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                  title: const Text("Change Password", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: _showChangePasswordDialog,
                ),

                // 3. Notifications
                _buildSectionHeader("NOTIFICATIONS"),
                SwitchListTile(
                  title: const Text("Likes & Reactions", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _notifLikes,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (v) {
                    setState(() => _notifLikes = v);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Comments & Replies", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _notifComments,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (v) {
                    setState(() => _notifComments = v);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("New Followers", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _notifFollows,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (v) {
                    setState(() => _notifFollows = v);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Direct Messages", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _notifMessages,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (v) {
                    setState(() => _notifMessages = v);
                    _saveSettings();
                  },
                ),

                // 4. Accounts & Safety
                _buildSectionHeader("SAFETY"),
                ListTile(
                  leading: const Icon(Icons.block_outlined, color: Colors.white70),
                  title: const Text("Blocked Accounts", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.volume_off_outlined, color: Colors.white70),
                  title: const Text("Muted Accounts", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: () {},
                ),

                // 5. Support & Logout
                _buildSectionHeader("MORE"),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: Colors.white70),
                  title: const Text("Help & Support", style: TextStyle(color: Colors.white)),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: _confirmLogout,
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }
}
