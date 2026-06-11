import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import '../profile/profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await _apiService.get('/social/notifications');
      if (response.statusCode == 200) {
        setState(() {
          _notifications = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFollowRequest(String requestId, bool accept) async {
    final endpoint = accept ? '/social/requests/$requestId/accept' : '/social/requests/$requestId/reject';
    try {
      final response = await _apiService.post(endpoint, {});
      if (response.statusCode == 200) {
        _fetchNotifications();
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text("No new activity", style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return _buildNotificationItem(n);
                  },
                ),
    );
  }

  Widget _buildNotificationItem(dynamic n) {
    String text = "";
    bool isRequest = n['type'] == "follow_request";

    switch (n['type']) {
      case "follow_request":
        text = "@${n['from_user']} requested to follow you";
        break;
      case "follow_accept":
        text = "@${n['from_user']} accepted your follow request";
        break;
      case "post_like":
        text = "@${n['from_user']} liked your post";
        break;
      default:
        text = "@${n['from_user']} interacted with you";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage("https://api.dicebear.com/7.x/avataaars/svg?seed=${n['from_user']}"),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
                Text("2h ago", style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          if (isRequest)
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _handleFollowRequest(n['metadata']['request_id'], true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(60, 30),
                  ),
                  child: const Text("Accept", style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _handleFollowRequest(n['metadata']['request_id'], false),
                  child: const Text("Ignore", style: TextStyle(fontSize: 12, color: Colors.white54)),
                ),
              ],
            )
        ],
      ),
    );
  }
}
