import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';

class ReelOptionsSheet extends StatefulWidget {
  final dynamic reel;
  final ApiService apiService;
  final VoidCallback? onRefresh;

  const ReelOptionsSheet({
    super.key,
    required this.reel,
    required this.apiService,
    this.onRefresh,
  });

  @override
  State<ReelOptionsSheet> createState() => _ReelOptionsSheetState();
}

class _ReelOptionsSheetState extends State<ReelOptionsSheet> {
  String? _myUsername;
  bool _isSaved = false;
  bool _isPinned = false;
  bool _isArchived = false;
  bool _commentsDisabled = false;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.reel['is_pinned'] == true;
    _isArchived = widget.reel['is_archived'] == true;
    _commentsDisabled = widget.reel['comments_disabled'] == true;
    _loadMyUsername();
  }

  Future<void> _loadMyUsername() async {
    const storage = FlutterSecureStorage();
    final userJson = await storage.read(key: 'user');
    if (userJson != null && mounted) {
      final u = jsonDecode(userJson);
      setState(() {
        _myUsername = u['username'] ?? u['anonymous_username'];
      });
    }
  }

  Future<void> _toggleSave() async {
    try {
      final reelId = widget.reel['id'] ?? widget.reel['_id'];
      if (_isSaved) {
        await widget.apiService.delete('/reels/$reelId/save');
      } else {
        await widget.apiService.post('/reels/$reelId/save', {});
      }
      setState(() => _isSaved = !_isSaved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isSaved ? "Saved to collection" : "Removed from saved")),
        );
      }
    } catch (_) {}
  }

  Future<void> _sendFeedback(String feedbackType) async {
    try {
      final reelId = widget.reel['id'] ?? widget.reel['_id'];
      await widget.apiService.post('/reels/$reelId/feedback', {'feedback_type': feedbackType});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback recorded. Feed updated.")),
        );
        if (widget.onRefresh != null) widget.onRefresh!();
      }
    } catch (_) {}
  }

  Future<void> _togglePin() async {
    try {
      final reelId = widget.reel['id'] ?? widget.reel['_id'];
      final res = await widget.apiService.post('/reels/$reelId/pin', {});
      if (res.statusCode == 200) {
        setState(() => _isPinned = !_isPinned);
        if (widget.onRefresh != null) widget.onRefresh!();
      }
    } catch (_) {}
  }

  Future<void> _toggleArchive() async {
    try {
      final reelId = widget.reel['id'] ?? widget.reel['_id'];
      final res = await widget.apiService.post('/reels/$reelId/archive', {});
      if (res.statusCode == 200) {
        setState(() => _isArchived = !_isArchived);
        if (mounted) Navigator.pop(context);
        if (widget.onRefresh != null) widget.onRefresh!();
      }
    } catch (_) {}
  }

  Future<void> _toggleComments() async {
    try {
      final reelId = widget.reel['id'] ?? widget.reel['_id'];
      final res = await widget.apiService.post('/reels/$reelId/comments-toggle', {});
      if (res.statusCode == 200) {
        setState(() => _commentsDisabled = !_commentsDisabled);
      }
    } catch (_) {}
  }

  Future<void> _deleteReel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Delete Reel?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("This cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final reelId = widget.reel['id'] ?? widget.reel['_id'];
        await widget.apiService.delete('/reels/$reelId');
        if (mounted) {
          Navigator.pop(context);
          if (widget.onRefresh != null) widget.onRefresh!();
        }
      } catch (_) {}
    }
  }

  void _showReportDialog() {
    final reasons = ["Spam", "Harassment", "Hate speech", "Violence", "Nudity or sexual content", "False information", "Other"];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Report Reel", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...reasons.map((r) => ListTile(
              title: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              onTap: () async {
                Navigator.pop(context); // close report sheet
                Navigator.pop(context); // close options sheet
                try {
                  final reelId = widget.reel['id'] ?? widget.reel['_id'];
                  await widget.apiService.post('/reels/$reelId/report', {'reason': r});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for reporting. We'll review it.")));
                  }
                } catch (_) {}
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.reel['author_id']?.toString() ?? '';
    final bool isMe = _myUsername != null && _myUsername == author;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          if (isMe) ...[
            // Owner Options
            ListTile(
              leading: const Icon(Icons.push_pin_outlined, color: Colors.white),
              title: Text(_isPinned ? "Unpin from profile" : "Pin to profile", style: const TextStyle(color: Colors.white)),
              onTap: _togglePin,
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: Colors.white),
              title: Text(_isArchived ? "Restore Reel" : "Archive Reel", style: const TextStyle(color: Colors.white)),
              onTap: _toggleArchive,
            ),
            ListTile(
              leading: const Icon(Icons.comment_outlined, color: Colors.white),
              title: Text(_commentsDisabled ? "Turn comments on" : "Turn comments off", style: const TextStyle(color: Colors.white)),
              onTap: _toggleComments,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text("Delete Reel", style: TextStyle(color: Colors.redAccent)),
              onTap: _deleteReel,
            ),
          ] else ...[
            // Viewer Options
            ListTile(
              leading: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Colors.white),
              title: Text(_isSaved ? "Remove from saved" : "Save Reel", style: const TextStyle(color: Colors.white)),
              onTap: _toggleSave,
            ),
            ListTile(
              leading: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.white),
              title: const Text("Interested", style: TextStyle(color: Colors.white)),
              onTap: () => _sendFeedback("interested"),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined, color: Colors.white),
              title: const Text("Not Interested", style: TextStyle(color: Colors.white)),
              onTap: () => _sendFeedback("not_interested"),
            ),
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent),
              title: const Text("Report Reel", style: TextStyle(color: Colors.redAccent)),
              onTap: _showReportDialog,
            ),
          ],
        ],
      ),
    );
  }
}
