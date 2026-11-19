import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  final _apiService = ApiService();
  List<dynamic> _archivedChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArchivedChats();
  }

  Future<void> _fetchArchivedChats() async {
    try {
      final res = await _apiService.get('/chats');
      if (res.statusCode == 200 && mounted) {
        final List allChats = jsonDecode(res.body);
        setState(() {
          // Filter chats where current user archived them
          _archivedChats = allChats.where((c) => c['is_archived'] == true).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unarchive(String chatId) async {
    try {
      await _apiService.post('/chats/$chatId/archive', {});
      _fetchArchivedChats();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Archived Chats", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _archivedChats.isEmpty
              ? const Center(child: Text("No archived conversations", style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  itemCount: _archivedChats.length,
                  itemBuilder: (context, index) {
                    final chat = _archivedChats[index];
                    final chatId = chat['_id'] ?? chat['id'];
                    final otherUser = chat['other_user'] ?? 'User';
                    final otherPhoto = chat['other_user_photo'];

                    return ListTile(
                      leading: SafeAvatar(avatarUrl: otherPhoto, username: otherUser.toString(), radius: 24),
                      title: Text("@$otherUser", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(chat['last_message'] ?? "", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      trailing: TextButton(
                        onPressed: () => _unarchive(chatId),
                        child: const Text("Unarchive", style: TextStyle(color: Color(0xFF6C63FF))),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherUser: otherUser.toString())),
                        ).then((_) => _fetchArchivedChats());
                      },
                    );
                  },
                ),
    );
  }
}
