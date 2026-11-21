import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import 'chat_screen.dart';
import '../random_chat/video_chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _apiService = ApiService();
  List<dynamic> _chats = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredChats = [];

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
        final List data = jsonDecode(response.body);
        setState(() {
          _chats = data;
          _filteredChats = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredChats = _chats);
      return;
    }
    setState(() {
      _filteredChats = _chats.where((c) {
        final otherUser = (c['other_user'] ?? '').toString().toLowerCase();
        final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
        return otherUser.contains(q) || lastMsg.contains(q);
      }).toList();
    });
  }

  void _startNewChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        List results = [];
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            padding: const EdgeInsets.all(20),
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("New Message", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Search username...",
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Color(0xFF0F0F1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
                  ),
                  onChanged: (q) async {
                    if (q.isEmpty) {
                      setModalState(() => results = []);
                      return;
                    }
                    try {
                      final res = await _apiService.get('/users/search?q=$q');
                      if (res.statusCode == 200) {
                        setModalState(() => results = jsonDecode(res.body));
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final u = results[index];
                      final uname = u['username'] ?? 'User';
                      return ListTile(
                        leading: SafeAvatar(avatarUrl: u['avatar_url'] ?? u['profile_photo_url'], username: uname, radius: 20),
                        title: Text("@$uname", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _startChat(uname);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text("Direct Messages", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
            tooltip: "Video Call",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoChatScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white, size: 22),
            tooltip: "New Message",
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Immediately Below Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: _filterSearch,
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _filterSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Conversation List (Single Continuous List)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _filteredChats.isEmpty
                    ? const Center(child: Text("No conversations yet", style: TextStyle(color: Colors.white38, fontSize: 13)))
                    : RefreshIndicator(
                        onRefresh: _fetchChats,
                        color: const Color(0xFF6C63FF),
                        child: ListView.builder(
                          itemCount: _filteredChats.length,
                          itemBuilder: (context, index) {
                            final chat = _filteredChats[index];
                            final chatId = chat['_id'] ?? chat['id'];
                            final otherUser = chat['other_user'] ?? 'User';
                            final otherPhoto = chat['other_user_photo'];
                            final bool isPinned = chat['is_pinned'] == true;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: SafeAvatar(
                                avatarUrl: otherPhoto,
                                username: otherUser.toString(),
                                radius: 24,
                              ),
                              title: Row(
                                children: [
                                  Text("@$otherUser", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 22),
                                    tooltip: "Send Snap",
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(chatId: chatId, otherUser: otherUser.toString()),
                                        ),
                                      );
                                    },
                                  ),
                                  PopupMenuButton<String>(
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
                      ),
          ),

          // Bottom Fixed Camera Shortcut
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color(0xFF1A1A2E),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VideoChatScreen()),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6C63FF), size: 20),
                  label: const Text("Camera", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
