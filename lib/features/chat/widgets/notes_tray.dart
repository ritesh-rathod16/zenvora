import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import '../chat_screen.dart';

class NotesTray extends StatefulWidget {
  const NotesTray({super.key});

  @override
  State<NotesTray> createState() => _NotesTrayState();
}

class _NotesTrayState extends State<NotesTray> {
  final _apiService = ApiService();
  List<dynamic> _notes = [];
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    try {
      const storage = FlutterSecureStorage();
      final userJson = await storage.read(key: 'user');
      if (userJson != null && mounted) {
        setState(() {
          _currentUser = jsonDecode(userJson);
        });
      }

      final res = await _apiService.get('/notes/feed');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _notes = jsonDecode(res.body);
        });
      }
    } catch (_) {}
  }

  void _showCreateNoteDialog() {
    final TextEditingController noteCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Leave a Note", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: "Share what's on your mind...",
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF0F0F1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _apiService.delete('/notes/delete');
                    _fetchNotes();
                  },
                  child: const Text("Delete Note", style: TextStyle(color: Colors.redAccent)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final text = noteCtrl.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    await _apiService.post('/notes/create', {'content': text, 'visibility': 'followers'});
                    _fetchNotes();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                  child: const Text("Share"),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = _currentUser?['username'] ?? _currentUser?['anonymous_username'] ?? 'You';
    final myAvatarUrl = _currentUser?['profile_photo_url'] ?? _currentUser?['avatar_url'];

    // Find my note if exists
    final myNote = _notes.firstWhere((n) => n['is_me'] == true, orElse: () => null);

    return SizedBox(
      height: 110,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          // My Note Bubble
          GestureDetector(
            onTap: _showCreateNoteDialog,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (myNote != null)
                        Positioned(
                          top: -26,
                          left: -10,
                          right: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF6C63FF), width: 1),
                            ),
                            child: Text(
                              myNote['content'],
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      SafeAvatar(avatarUrl: myAvatarUrl, username: myUsername, radius: 30),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                          child: const Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("Your Note", style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),

          // Others' Notes
          ..._notes.where((n) => n['is_me'] != true).map((note) {
            final author = note['user_id'] ?? 'User';
            final authorPhoto = note['author_photo'];
            final content = note['content'] ?? '';

            return GestureDetector(
              onTap: () async {
                final res = await ApiService().post('/chats/start/$author', {});
                if (res.statusCode == 200 && context.mounted) {
                  final chat = jsonDecode(res.body);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat['_id'] ?? chat['id'], otherUser: author)),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -26,
                          left: -10,
                          right: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ),
                        ),
                        SafeAvatar(avatarUrl: authorPhoto, username: author, radius: 30),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("@$author", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
