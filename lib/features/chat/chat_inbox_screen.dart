import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import 'chat_screen.dart';
import 'widgets/notes_tray.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  List<dynamic> _chats = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
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
              builder: (_) => ChatScreen(chatId: chat['_id'] ?? chat['id'], otherUser: username),
            ),
          ).then((_) => _fetchChats());
        }
      }
    } catch (_) {}
  }

  Future<void> _togglePin(String chatId) async {
    try {
      await _apiService.post('/chats/$chatId/pin', {});
      _fetchChats();
    } catch (_) {}
  }

  Future<void> _toggleArchive(String chatId) async {
    try {
      await _apiService.post('/chats/$chatId/archive', {});
      _fetchChats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conversation archived")));
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

  List<dynamic> _filterChats(int tabIndex) {
    if (tabIndex == 1) {
      return _chats.where((c) => c['category'] == 'primary').toList();
    } else if (tabIndex == 2) {
      return _chats.where((c) => c['category'] == 'general').toList();
    } else if (tabIndex == 3) {
      return _chats.where((c) => c['category'] == 'requests').toList();
    }
    return _chats;
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
                  : Column(
                      children: [
                        // Notes Tray (Cleanly separated at top)
                        const NotesTray(),
                        const Divider(color: Colors.white10, height: 1),

                        // Tab Bar for Categories
                        Container(
                          color: const Color(0xFF1A1A2E),
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: const Color(0xFF6C63FF),
                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: const Color(0xFF6C63FF),
                            unselectedLabelColor: Colors.white54,
                            tabs: const [
                              Tab(text: "All"),
                              Tab(text: "Primary"),
                              Tab(text: "General"),
                              Tab(text: "Requests"),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),

                        // Chat List TabBarView
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildChatList(_chats),
                              _buildChatList(_filterChats(1)),
                              _buildChatList(_filterChats(2)),
                              _buildChatList(_filterChats(3)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<dynamic> list) {
    if (list.isEmpty) {
      return const Center(child: Text("No conversations yet.", style: TextStyle(color: Colors.white38)));
    }
    return RefreshIndicator(
      onRefresh: _fetchChats,
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final chat = list[index];
          final chatId = chat['_id'] ?? chat['id'];
          final otherUser = chat['other_user'] ?? 'User';
          final otherPhoto = chat['other_user_photo'];
          final bool isPinned = chat['is_pinned'] == true;

          return ListTile(
            leading: SafeAvatar(
              avatarUrl: otherPhoto,
              username: otherUser.toString(),
              radius: 24,
            ),
            title: Row(
              children: [
                Text("@$otherUser", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (isPinned) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.push_pin_rounded, color: Color(0xFF6C63FF), size: 14),
                ],
              ],
            ),
            subtitle: Text(
              chat['last_message'] ?? "Start a conversation",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
              color: const Color(0xFF1A1A2E),
              onSelected: (val) {
                if (val == 'pin') _togglePin(chatId);
                if (val == 'archive') _toggleArchive(chatId);
                if (val == 'delete') _deleteChat(chatId);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pin', child: Text(isPinned ? "Unpin chat" : "Pin chat", style: const TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'archive', child: Text("Archive chat", style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'delete', child: Text("Delete chat", style: TextStyle(color: Colors.redAccent))),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: chatId, otherUser: otherUser.toString()),
                ),
              ).then((_) => _fetchChats());
            },
          );
        },
      ),
    );
  }
}
