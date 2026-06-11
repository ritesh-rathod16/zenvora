  import 'package:flutter/material.dart';
  import 'dart:convert';
  import '../../core/services/api_service.dart';
  class AdminChatsScreen extends StatefulWidget {
    const AdminChatsScreen({super.key});

    @override
    State<AdminChatsScreen> createState() => _AdminChatsScreenState();
  }

  class _AdminChatsScreenState extends State<AdminChatsScreen> {
    final _apiService = ApiService();
    List<dynamic> _chats = [];
    bool _isLoading = true;

    @override
    void initState() {
      super.initState();
      _fetchChats();
    }

    Future<void> _fetchChats() async {
      try {
        final response = await _apiService.get('/admin/chats');
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

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text("Reported Chats")),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _chats.isEmpty
                ? const Center(child: Text("No flagged conversations."))
                : ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.forum)),
                        title: Text("Chat: ${chat['participants'].join(' & ')}"),
                        subtitle: Text("Last: ${chat['last_message']}"),
                        onTap: () {
                          // Admins can view conversation history for moderation
                        },
                      );
                    },
                  ),
      );
    }
  }
