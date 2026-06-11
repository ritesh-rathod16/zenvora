import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUser;

  const ChatScreen({super.key, required this.chatId, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<dynamic> _messages = [];
  final _messageController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = true;
  String _autoDeleteMode = "none";

  @override
  void initState() {
    super.initState();
    _fetchChatDetails();
    _fetchMessages();
  }

  Future<void> _fetchChatDetails() async {
    try {
      final response = await _apiService.get('/chats/');
      if (response.statusCode == 200) {
        final List<dynamic> chats = jsonDecode(response.body);
        final currentChat = chats.firstWhere((c) => c['_id'] == widget.chatId);
        setState(() {
          _autoDeleteMode = currentChat['auto_delete_mode'] ?? "none";
        });
      }
    } catch (e) {}
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await _apiService.get('/chats/${widget.chatId}/messages');
      if (response.statusCode == 200) {
        setState(() {
          _messages.clear();
          _messages.addAll(jsonDecode(response.body));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _sendMessage({String type = "text", String? content}) async {
    final text = content ?? _messageController.text;
    if (text.isEmpty && type == "text") return;
    
    if (type == "text") _messageController.clear();

    try {
      final response = await _apiService.post('/chats/${widget.chatId}/send', {
        'content': text,
        'message_type': type,
      });
      if (response.statusCode == 200) {
        setState(() {
          _messages.add(jsonDecode(response.body));
        });
      }
    } catch (e) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // For now, simulate sending image by sending its path or a placeholder
      // In production, upload to /media/upload and send returned URL
      _sendMessage(type: "image", content: "📷 Photo sent");
    }
  }

  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Chat Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text("Auto Delete Messages", style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 12),
              _buildModeOption(setModalState, "none", "Off"),
              _buildModeOption(setModalState, "instant", "Immediately"),
              _buildModeOption(setModalState, "24h", "After 24 hours"),
              _buildModeOption(setModalState, "7d", "After 7 days"),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(StateSetter setModalState, String mode, String label) {
    bool isSelected = _autoDeleteMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF6C63FF) : Colors.white)),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF6C63FF)) : null,
      onTap: () async {
        final res = await _apiService.patch('/chats/${widget.chatId}', {'auto_delete_mode': mode});
        if (res.statusCode == 200) {
          setState(() => _autoDeleteMode = mode);
          setModalState(() {});
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Auto-delete set to $label")));
        }
      },
    );
  }

  void _handleMenuOption(String choice) async {
    switch (choice) {
      case 'Delete Chat':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text("Delete Conversation"),
            content: const Text("This will permanently remove this chat and all messages."),
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
          final res = await _apiService.delete('/chats/${widget.chatId}');
          if (res.statusCode == 200 && mounted) Navigator.pop(context);
        }
        break;
      case 'Chat Settings':
        _showChatSettings();
        break;
      case 'Block User':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Blocked")));
        break;
      case 'Report User':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Submitted")));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage("https://api.dicebear.com/7.x/avataaars/svg?seed=${widget.otherUser}"),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("@${widget.otherUser}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (_autoDeleteMode != "none")
                    Text("Auto-delete: $_autoDeleteMode", style: const TextStyle(fontSize: 10, color: Colors.amberAccent)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Colors.white70),
            onPressed: () {
              // Trigger Voice Call logic
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white70),
            onPressed: () {
              // Trigger Video Call logic
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuOption,
            itemBuilder: (context) => [
              'Chat Settings', 'Mute Notifications', 'Block User', 'Report User', 'Delete Chat'
            ].map((s) => PopupMenuItem(value: s, child: Text(s, style: TextStyle(color: s == 'Delete Chat' ? Colors.redAccent : Colors.white)))).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[_messages.length - 1 - index];
                    final isMe = msg['sender_id'] != widget.otherUser;
                    return _buildMessageBubble(msg, isMe);
                  },
                ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMe) {
    bool isImage = msg['message_type'] == "image";
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage)
              const Icon(Icons.image, color: Colors.white70, size: 40)
            else
              Text(msg['content'], style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              "12:45 PM", 
              style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6C63FF)),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: () => _sendMessage(),
            backgroundColor: const Color(0xFF6C63FF),
            elevation: 0,
            child: const Icon(Icons.send, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
