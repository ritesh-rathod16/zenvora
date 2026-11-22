import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import '../random_chat/video_chat_screen.dart';
import 'chat_info_screen.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

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

  String _autoDeleteMode = "never_delete"; // immediately_delete, delete_24h, never_delete
  String? _otherUserPhoto;
  String? _otherUserDisplayName;
  String? _replyingToMsgId;
  String? _replyingToContent;

  @override
  void initState() {
    super.initState();
    _fetchOtherUserProfile();
    _fetchChatDetails();
    _fetchMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchOtherUserProfile() async {
    try {
      final res = await _apiService.get('/users/${widget.otherUser}');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _otherUserDisplayName = data['display_name'];
          _otherUserPhoto = data['profile_photo_url'] ?? data['avatar_url'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchChatDetails() async {
    try {
      final response = await _apiService.get('/chats/${widget.chatId}/details');
      if (response.statusCode == 200 && mounted) {
        final currentChat = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _autoDeleteMode = currentChat['auto_delete_mode'] ?? "never_delete";
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await _apiService.get('/chats/${widget.chatId}/messages');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(jsonDecode(response.body));
          _isLoading = false;
        });

        // Mark unread partner messages as viewed
        for (var msg in _messages) {
          if (msg['is_me'] == false && msg['viewed_at'] == null) {
            _apiService.post('/chats/${widget.chatId}/messages/${msg['id'] ?? msg['_id']}/view', {});
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendMessage({String type = "text", String? content, String? attachmentUrl}) async {
    final text = content ?? _messageController.text.trim();
    if (text.isEmpty && type == "text" && attachmentUrl == null) return;

    if (type == "text") _messageController.clear();
    final replyId = _replyingToMsgId;
    setState(() {
      _replyingToMsgId = null;
      _replyingToContent = null;
    });

    try {
      final response = await _apiService.post('/chats/${widget.chatId}/send', {
        'content': text,
        'message_type': type,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (replyId != null) 'reply_to_message_id': replyId,
      });
      if (response.statusCode == 200 && mounted) {
        _fetchMessages();
      }
    } catch (_) {}
  }

  Future<void> _sendMedia() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sending media...")),
      );
      try {
        final res = await _apiService.uploadFile('/chats/${widget.chatId}/upload-media', file.path);
        if (res.statusCode == 200) {
          _fetchMessages();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Media upload failed: $e")),
          );
        }
      }
    }
  }

  Future<void> _reactToMessage(String msgId, String emoji) async {
    try {
      final res = await _apiService.post('/chats/${widget.chatId}/messages/$msgId/react', {
        'emoji': emoji,
      });
      if (res.statusCode == 200) {
        _fetchMessages();
      }
    } catch (_) {}
  }

  Future<void> _deleteMessage(String msgId) async {
    try {
      final res = await _apiService.delete('/chats/${widget.chatId}/messages/$msgId');
      if (res.statusCode == 200) {
        _fetchMessages();
      }
    } catch (_) {}
  }

  Future<void> _doubleTapMessage(String messageId) async {
    try {
      await _apiService.post('/chats/${widget.chatId}/messages/$messageId/react', {
        'emoji': '❤️'
      });
      _fetchMessages();
    } catch (_) {}
  }

  Future<void> _sendSnapCamera() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image != null && mounted) {
      final bool? isViewOnce = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text("Send Snap", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text("Do you want to send this as a View Once media?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Normal Photo")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
              child: const Text("View Once"),
            ),
          ],
        ),
      );

      if (isViewOnce != null && mounted) {
        try {
          final res = await _apiService.uploadFile('/media/chat/upload', image.path);
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final url = data['url'] ?? data['profile_photo_url'];
            _sendMessage(
              type: isViewOnce ? "view_once" : "photo",
              content: isViewOnce ? "📷 View Once Photo" : "📷 Photo",
              attachmentUrl: url,
            );
          }
        } catch (_) {}
      }
    }
  }

  void _openChatInfo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(chatId: widget.chatId, otherUser: widget.otherUser),
      ),
    );

    if (result == "deleted" || result == "blocked") {
      if (mounted) Navigator.pop(context);
    } else {
      _fetchChatDetails();
      _fetchMessages();
    }
  }



  Widget _getDisappearingIcon() {
    switch (_autoDeleteMode) {
      case "immediately_delete":
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.orangeAccent),
            SizedBox(width: 4),
            Text("Immediately Delete", style: TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ],
        );
      case "delete_24h":
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 12, color: Colors.amberAccent),
            SizedBox(width: 4),
            Text("Disappears in 24h", style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ],
        );
      case "never_delete":
      default:
        return const SizedBox.shrink();
    }
  }

  void _showMessageOptions(dynamic msg, bool isMe) {
    final msgId = msg['id'] ?? msg['_id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Emoji Reaction Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '😮', '🔥', '👏', '👍'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _reactToMessage(msgId, emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.white),
              title: const Text("Reply", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyingToMsgId = msgId;
                  _replyingToContent = msg['content'];
                });
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text("Delete Message", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msgId);
                },
              ),
          ],
        ),
      ),
    );
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
        title: GestureDetector(
          onTap: _openChatInfo,
          child: Row(
            children: [
              SafeAvatar(
                avatarUrl: _otherUserPhoto,
                username: widget.otherUser,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _otherUserDisplayName ?? "@${widget.otherUser}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    _getDisappearingIcon(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: Colors.greenAccent),
            tooltip: "Voice Call",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoChatScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            tooltip: "Chat Settings & Info",
            onPressed: _openChatInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _messages.isEmpty
                    ? const Center(child: Text("Say hello to start chatting! 👋", style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[_messages.length - 1 - index];
                          final isMe = msg['is_me'] == true;
                          return MessageBubble(
                            message: msg,
                            isMe: isMe,
                            onLongPress: () => _showMessageOptions(msg, isMe),
                            onDoubleTap: () => _doubleTapMessage(msg['_id'] ?? msg['id']),
                          );
                        },
                      ),
          ),
          MessageComposer(
            controller: _messageController,
            replyingToContent: _replyingToContent,
            onCancelReply: () => setState(() {
              _replyingToMsgId = null;
              _replyingToContent = null;
            }),
            onSend: () => _sendMessage(),
            onCamera: _sendSnapCamera,
            onGallery: _sendMedia,
          ),
        ],
      ),
    );
  }
}
