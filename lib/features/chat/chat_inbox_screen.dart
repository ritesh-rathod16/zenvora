import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _apiService = ApiService();
  List<dynamic> _chats = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchChats() async {
    try {
      final response = await _apiService.get('/chats');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _chats = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _searchPeople(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final response = await _apiService.get('/users/search?q=$query');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  void _startChat(String username) async {
    try {
      final response = await _apiService.post('/chats/start/$username', {});
      if (response.statusCode == 200) {
        final chat = jsonDecode(response.body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chat['_id'], otherUser: username),
            ),
          ).then((_) => _fetchChats());
        }
      }
    } catch (_) {}
  }

  void _deleteChat(String chatId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Delete Chat?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove the conversation.", style: TextStyle(color: Colors.white70)),
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
        final response = await _apiService.delete('/chats/$chatId');
        if (response.statusCode == 200) {
          _fetchChats();
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Search Username...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.white38)),
                style: const TextStyle(color: Colors.white),
                onChanged: _searchPeople,
              )
            : const Text("Direct Messages", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching && _searchResults.isNotEmpty)
            Expanded(
              child: Container(
                color: const Color(0xFF0F0F1A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("PEOPLE", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final uname = user['username'] ?? 'User';
                          return ListTile(
                            leading: SafeAvatar(
                              avatarUrl: user['avatar_url'] ?? user['profile_photo_url'],
                              username: uname,
                              radius: 20,
                            ),
                            title: Text("@$uname", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onTap: () => _startChat(uname),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isSearching || (_isSearching && _searchResults.isEmpty))
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                  : _chats.isEmpty
                      ? const Center(child: Text("No conversations yet.", style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: _chats.length,
                          itemBuilder: (context, index) {
                            final chat = _chats[index];
                            final otherUser = chat['other_user'] ?? 'User';
                            final otherPhoto = chat['other_user_photo'];

                            return ListTile(
                              leading: SafeAvatar(
                                avatarUrl: otherPhoto,
                                username: otherUser.toString(),
                                radius: 24,
                              ),
                              title: Text("@$otherUser", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                chat['last_message'] ?? "Start a conversation",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                onPressed: () => _deleteChat(chat['_id'] ?? chat['id']),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(chatId: chat['_id'] ?? chat['id'], otherUser: otherUser.toString()),
                                  ),
                                ).then((_) => _fetchChats());
                              },
                            );
                          },
                        ),
            ),
        ],
      ),
    );
  }
}
