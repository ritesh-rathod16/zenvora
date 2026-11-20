import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMe;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final Function(String)? onStoryTap;
  final Function(String)? onPostTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.onDoubleTap,
    this.onStoryTap,
    this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    final String type = message['message_type'] ?? 'text';
    final String content = message['content'] ?? '';
    final String? attachmentUrl = message['attachment_url'];
    final List reactions = message['reactions'] as List? ?? [];
    final String mode = message['deletion_mode'] ?? 'never_delete';
    final bool isRead = message['viewed_at'] != null;

    if (type == "system") {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: Border.all(
              color: isMe ? const Color(0xFF8B85FF) : Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attachment Image or Video Thumbnail
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

              // Context Header for Story Reply or Shared Post
              if (type == "story_reply" || type == "story_reaction") ...[
                GestureDetector(
                  onTap: () {
                    if (onStoryTap != null && message['story_id'] != null) {
                      onStoryTap!(message['story_id']);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent, size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Replied to story",
                            style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (type == "post_share") ...[
                GestureDetector(
                  onTap: () {
                    if (onPostTap != null && message['post_id'] != null) {
                      onPostTap!(message['post_id']);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.share_rounded, color: Color(0xFF00F0FF), size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Shared a post",
                            style: TextStyle(color: Color(0xFF00F0FF), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Message Content
              Text(
                content,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
              ),

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
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 13,
                      color: isRead ? const Color(0xFF00F0FF) : Colors.white54,
                    ),
                ],
              ),

              // Reaction Emojis
              if (reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: reactions.map((r) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
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
}
