import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import '../../widgets/safe_avatar.dart';

class CloseFriendsScreen extends StatefulWidget {
  const CloseFriendsScreen({super.key});

  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsScreenState();
}

class _CloseFriendsScreenState extends State<CloseFriendsScreen> {
  final _apiService = ApiService();
  List<dynamic> _closeFriends = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCloseFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCloseFriends() async {
    try {
      final res = await _apiService.get('/stories/close-friends');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _closeFriends = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _searchPeople(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final res = await _apiService.get('/users/search?q=${q.trim()}');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _searchResults = jsonDecode(res.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _addCloseFriend(String username) async {
    try {
      final res = await _apiService.post('/stories/close-friends/$username', {});
      if (res.statusCode == 200) {
        _fetchCloseFriends();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added @$username to Close Friends")),
        );
      }
    } catch (_) {}
  }

  Future<void> _removeCloseFriend(String username) async {
    try {
      final res = await _apiService.delete('/stories/close-friends/$username');
      if (res.statusCode == 200) {
        _fetchCloseFriends();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Removed @$username from Close Friends")),
        );
      }
    } catch (_) {}
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
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search Username...",
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: _searchPeople,
              )
            : const Text("Close Friends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : Column(
              children: [
                if (_isSearching && _searchResults.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final u = _searchResults[index];
                        final uname = u['username'] ?? 'User';
                        final isAlready = _closeFriends.any((cf) => cf['username'] == uname);

                        return ListTile(
                          leading: SafeAvatar(
                            avatarUrl: u['avatar_url'] ?? u['profile_photo_url'],
                            username: uname,
                            radius: 20,
                          ),
                          title: Text("@$uname", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: isAlready
                              ? const Text("Added", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                              : ElevatedButton(
                                  onPressed: () => _addCloseFriend(uname),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                                  child: const Text("Add"),
                                ),
                        );
                      },
                    ),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Stories shared with Close Friends display a green badge and are only visible to people on this list.",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: _closeFriends.isEmpty
                        ? const Center(child: Text("No close friends added yet.", style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: _closeFriends.length,
                            itemBuilder: (context, index) {
                              final cf = _closeFriends[index];
                              final uname = cf['username'] ?? 'User';

                              return ListTile(
                                leading: SafeAvatar(
                                  avatarUrl: cf['profile_photo_url'],
                                  username: uname,
                                  radius: 20,
                                ),
                                title: Text("@$uname", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(cf['display_name'] ?? uname, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                trailing: TextButton(
                                  onPressed: () => _removeCloseFriend(uname),
                                  child: const Text("Remove", style: TextStyle(color: Colors.redAccent)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}
