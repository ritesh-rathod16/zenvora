import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  final List<String> _selectedParticipants = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _searchPeople(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final res = await _apiService.get('/users/search?q=$query');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _searchResults = jsonDecode(res.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || _selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a group name and select at least one member")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _apiService.post('/chats/group/create', {
        'group_name': name,
        'participants': _selectedParticipants,
      });

      if (res.statusCode == 200 && mounted) {
        final chat = jsonDecode(res.body);
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: chat['_id'] ?? chat['id'], otherUser: name),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to create group: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("New Group Chat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: const Text("Create", style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _groupNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Group Name",
                labelStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1A1A2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Add Members", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search users...",
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF1A1A2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
              ),
              onChanged: _searchPeople,
            ),
            const SizedBox(height: 16),
            if (_selectedParticipants.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: _selectedParticipants.map((p) => Chip(
                  label: Text("@$p", style: const TextStyle(color: Colors.white)),
                  backgroundColor: const Color(0xFF6C63FF),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                  onDeleted: () => setState(() => _selectedParticipants.remove(p)),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final u = _searchResults[index];
                  final uname = u['username'] ?? 'User';
                  final isSelected = _selectedParticipants.contains(uname);

                  return ListTile(
                    leading: SafeAvatar(avatarUrl: u['avatar_url'] ?? u['profile_photo_url'], username: uname, radius: 20),
                    title: Text("@$uname", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF6C63FF),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedParticipants.add(uname);
                          } else {
                            _selectedParticipants.remove(uname);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedParticipants.remove(uname);
                        } else {
                          _selectedParticipants.add(uname);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
