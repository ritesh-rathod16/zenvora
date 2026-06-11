import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: _chats.isEmpty
          ? const Center(child: Text("No conversations yet. Start discovering!"))
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                // Display the other participant's name
                final otherUser = chat['participants'][0]; // Simple logic for demo

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage("https://api.dicebear.com/7.x/avataaars/svg?seed=$otherUser"),
                  ),
                  title: Text(
                    "@$otherUser",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat['last_message'] ?? "Start a conversation",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: const Text("12:45 PM", style: TextStyle(fontSize: 10, color: Colors.white30)),
                  onTap: () {},
                );
              },
            ),
    );
  }
}
