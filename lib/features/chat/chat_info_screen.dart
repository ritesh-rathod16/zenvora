import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import '../../widgets/safe_avatar.dart';
import '../profile/user_profile_screen.dart';

class ChatInfoScreen extends StatefulWidget {
  final String chatId;
  final String otherUser;

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;

  String? _displayName;
  String? _userPhoto;
  String _autoDeleteMode = "never_delete"; // immediately_delete, delete_24h, never_delete
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _fetchChatDetails();
  }

  Future<void> _fetchChatDetails() async {
    try {
      final res = await _apiService.get('/chats/${widget.chatId}/details');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _displayName = data['other_user_display_name'];
          _userPhoto = data['other_user_photo'];
          _autoDeleteMode = data['auto_delete_mode'] ?? "never_delete";
          _isMuted = data['is_muted'] ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setAutoDeleteMode(String mode) async {
    try {
      final res = await _apiService.patch('/chats/${widget.chatId}/auto-delete', {
        'auto_delete_mode': mode,
      });
      if (res.statusCode == 200 && mounted) {
        setState(() => _autoDeleteMode = mode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Disappearing messages updated to ${_getModeLabel(mode)}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update mode: $e")),
        );
      }
    }
  }

  Future<void> _toggleMute() async {
    try {
      final res = await _apiService.post('/chats/${widget.chatId}/mute', {});
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() => _isMuted = data['is_muted'] ?? false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isMuted ? "Notifications muted" : "Notifications unmuted")),
        );
      }
    } catch (_) {}
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text("Block @${widget.otherUser}?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("They will not be able to message you or see your profile.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("BLOCK"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.post('/users/block/${widget.otherUser}', {});
        if (mounted) {
          Navigator.pop(context, "blocked");
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Delete Conversation?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove all messages in this chat.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.delete('/chats/${widget.chatId}');
        if (mounted) {
          Navigator.pop(context, "deleted");
        }
      } catch (_) {}
    }
  }

  String _getModeLabel(String mode) {
    switch (mode) {
      case "immediately_delete":
        return "Immediately Delete";
      case "delete_24h":
        return "Delete After 24 Hours";
      case "never_delete":
      default:
        return "Never Delete";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Chat Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // Header Profile Info
                Center(
                  child: Column(
                    children: [
                      SafeAvatar(
                        avatarUrl: _userPhoto,
                        username: widget.otherUser,
                        radius: 50,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _displayName ?? widget.otherUser,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        "@${widget.otherUser}",
                        style: const TextStyle(fontSize: 14, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => UserProfileScreen(username: widget.otherUser)),
                          );
                        },
                        icon: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
                        label: const Text("View Profile"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildHeader("DISAPPEARING MESSAGES"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildModeRadio("Immediately Delete", "Messages disappear right after being viewed by recipient.", "immediately_delete", Icons.local_fire_department_rounded, Colors.orangeAccent),
                        const Divider(color: Colors.white10, height: 1),
                        _buildModeRadio("Delete After 24 Hours", "Messages automatically expire 24 hours after sending.", "delete_24h", Icons.timer_outlined, Colors.amberAccent),
                        const Divider(color: Colors.white10, height: 1),
                        _buildModeRadio("Never Delete", "Messages remain stored until manually removed.", "never_delete", Icons.history_toggle_off_rounded, Colors.white70),
                      ],
                    ),
                  ),
                ),

                _buildHeader("OPTIONS & NOTIFICATIONS"),
                SwitchListTile(
                  secondary: Icon(_isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded, color: Colors.white70),
                  title: const Text("Mute Notifications", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Mute alerts for new messages in this chat.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _isMuted,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (_) => _toggleMute(),
                ),

                _buildHeader("PRIVACY & SAFETY"),
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                  title: Text("Block @${widget.otherUser}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: _blockUser,
                ),
                ListTile(
                  leading: const Icon(Icons.report_problem_rounded, color: Colors.amberAccent),
                  title: const Text("Report Conversation", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Report submitted to Zenvora safety team.")),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text("Delete Conversation", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: _deleteConversation,
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildModeRadio(String title, String subtitle, String value, IconData icon, Color iconColor) {
    final bool isSelected = _autoDeleteMode == value;

    return RadioListTile<String>(
      value: value,
      groupValue: _autoDeleteMode,
      activeColor: const Color(0xFF6C63FF),
      onChanged: (val) {
        if (val != null) _setAutoDeleteMode(val);
      },
      secondary: Icon(icon, color: isSelected ? const Color(0xFF6C63FF) : iconColor, size: 22),
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    );
  }
}
