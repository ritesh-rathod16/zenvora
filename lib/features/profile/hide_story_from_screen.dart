import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import '../../widgets/safe_avatar.dart';

class HideStoryFromScreen extends StatefulWidget {
  const HideStoryFromScreen({super.key});

  @override
  State<HideStoryFromScreen> createState() => _HideStoryFromScreenState();
}

class _HideStoryFromScreenState extends State<HideStoryFromScreen> {
  final _apiService = ApiService();
  List<dynamic> _hiddenUsers = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHiddenUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHiddenUsers() async {
    try {
      final res = await _apiService.get('/stories/hide-from');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _hiddenUsers = jsonDecode(res.body);
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

  Future<void> _hideFromUser(String username) async {
    try {
      final res = await _apiService.post('/stories/hide-from/$username', {});
      if (res.statusCode == 200) {
        _fetchHiddenUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hiding stories from @$username")),
        );
      }
    } catch (_) {}
  }

  Future<void> _unhideUser(String username) async {
    try {
      final res = await _apiService.delete('/stories/hide-from/$username');
      if (res.statusCode == 200) {
        _fetchHiddenUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unhid stories from @$username")),
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
            : const Text("Hide Story From", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        final isAlready = _hiddenUsers.any((hu) => hu['username'] == uname);

                        return ListTile(
                          leading: SafeAvatar(
                            avatarUrl: u['avatar_url'] ?? u['profile_photo_url'],
                            username: uname,
                            radius: 20,
                          ),
                          title: Text("@$uname", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: isAlready
                              ? const Text("Hidden", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                              : ElevatedButton(
                                  onPressed: () => _hideFromUser(uname),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  child: const Text("Hide"),
                                ),
                        );
                      },
                    ),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Hide your stories and live videos from specific people. They will not be notified.",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: _hiddenUsers.isEmpty
                        ? const Center(child: Text("You haven't hidden stories from anyone.", style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: _hiddenUsers.length,
                            itemBuilder: (context, index) {
                              final hu = _hiddenUsers[index];
                              final uname = hu['username'] ?? 'User';

                              return ListTile(
                                leading: SafeAvatar(
                                  avatarUrl: hu['profile_photo_url'],
                                  username: uname,
                                  radius: 20,
                                ),
                                title: Text("@$uname", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(hu['display_name'] ?? uname, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                trailing: TextButton(
                                  onPressed: () => _unhideUser(uname),
                                  child: const Text("Unhide", style: TextStyle(color: Colors.blueAccent)),
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
