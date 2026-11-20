import 'package:flutter/material.dart';

class MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final String? replyingToContent;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const MessageComposer({
    super.key,
    required this.controller,
    this.replyingToContent,
    required this.onCancelReply,
    required this.onSend,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingToContent != null)
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
                      "Replying to: $replyingToContent",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                    onPressed: onCancelReply,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6C63FF)),
                tooltip: "Send Snap / View Once",
                onPressed: onCamera,
              ),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white70),
                onPressed: onGallery,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: "Message...",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black26,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C63FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
