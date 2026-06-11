import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _apiService = ApiService();
  bool _sendEmail = false;
  bool _isSending = false;

  void _sendBroadcast() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) return;
    
    setState(() => _isSending = true);
    try {
      final response = await _apiService.post('/admin/broadcast', {
        'title': _titleController.text,
        'message': _messageController.text,
        'send_email': _sendEmail,
      });
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Broadcast sent successfully!"),
              backgroundColor: Colors.green,
            )
          );
          _titleController.clear();
          _messageController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "COMPOSER",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "Announcement Title",
              fillColor: const Color(0xFF1A1A2E),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: "Write your platform-wide message here...",
              fillColor: const Color(0xFF1A1A2E),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              title: const Text("Email Broadcast", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: const Text("Send this message to all verified user emails.", style: TextStyle(fontSize: 11, color: Colors.white38)),
              value: _sendEmail,
              activeColor: const Color(0xFF6C63FF),
              onChanged: (v) => setState(() => _sendEmail = v),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isSending ? null : _sendBroadcast,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
            ),
            child: _isSending 
              ? const CircularProgressIndicator(color: Colors.white) 
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 20),
                    SizedBox(width: 12),
                    Text("LAUNCH BROADCAST", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
