import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import '../profile/user_profile_screen.dart';
import 'chat_info_screen.dart';

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

  void _openProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(username: username)),
    );
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
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
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
                          return _buildMessageItem(msg, isMe);
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(dynamic msg, bool isMe) {
    final String type = msg['message_type'] ?? 'text';
    final String content = msg['content'] ?? '';
    final String? attachmentUrl = msg['attachment_url'];
    final List reactions = msg['reactions'] as List? ?? [];
    final String mode = msg['deletion_mode'] ?? 'never_delete';

    if (type == "system") {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
              // Attachment Media if present
              if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: attachmentUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 180, color: Colors.white10),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // Story or Post Share Context
              if (type == "post_share" || type == "story_reply" || type == "story_reaction") ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type == "post_share" ? Icons.share_rounded : Icons.auto_awesome_rounded,
                        color: type == "post_share" ? const Color(0xFF00F0FF) : Colors.amberAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          content,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Text(content, style: const TextStyle(color: Colors.white, fontSize: 14)),

              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (mode == "immediately_delete")
                    const Icon(Icons.local_fire_department_rounded, size: 10, color: Colors.orangeAccent)
                  else if (mode == "delete_24h")
                    const Icon(Icons.timer_outlined, size: 10, color: Colors.amberAccent),
                  const Spacer(),
                  if (isMe)
                    Icon(
                      msg['viewed_at'] != null ? Icons.done_all_rounded : (msg['delivered_at'] != null ? Icons.done_all_rounded : Icons.done_rounded),
                      size: 12,
                      color: msg['viewed_at'] != null ? const Color(0xFF00F0FF) : Colors.white54,
                    ),
                ],
              ),

              // Reactions list
              if (reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: reactions.map((r) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                      child: Text("${r['emoji']}", style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
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
      child: Column(
        children: [
          if (_replyingToContent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Replying to: $_replyingToContent",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                    onPressed: () => setState(() {
                      _replyingToMsgId = null;
                      _replyingToContent = null;
                    }),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white70),
                onPressed: _sendMedia,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
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
        ],
      ),
    );
  }
}
