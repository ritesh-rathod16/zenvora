import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
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

  Future<void> _fetchChats() async {
    try {
      final response = await _apiService.get('/chats');
      if (response.statusCode == 200) {
        setState(() {
          _chats = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _searchPeople(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final response = await _apiService.get('/users/search?q=$query');
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (e) {}
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
    } catch (e) {}
  }

  void _deleteChat(String chatId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat?"),
        content: const Text("This will permanently remove the conversation."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
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
      } catch (e) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Search Username...", border: InputBorder.none),
                style: const TextStyle(color: Colors.white),
                onChanged: _searchPeople,
              )
            : const Text("Messages"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
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
                color: const Color(0xFF0F0F1E),
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
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(user['profile_photo_url'] ?? "https://api.dicebear.com/7.x/avataaars/svg?seed=${user['username']}"),
                            ),
                            title: Text("@${user['username']}"),
                            onTap: () => _startChat(user['username']),
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
                  ? const Center(child: CircularProgressIndicator())
                  : _chats.isEmpty
                      ? const Center(child: Text("No conversations yet."))
                      : ListView.builder(
                          itemCount: _chats.length,
                          itemBuilder: (context, index) {
                            final chat = _chats[index];
                            final otherUser = chat['participants'][0];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage("https://api.dicebear.com/7.x/avataaars/svg?seed=$otherUser"),
                              ),
                              title: Text("@$otherUser", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(chat['last_message'] ?? "Start a conversation", maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                onPressed: () => _deleteChat(chat['_id']),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(chatId: chat['_id'], otherUser: otherUser),
                                  ),
                                );
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
