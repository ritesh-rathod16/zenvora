import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';
import '../profile/user_profile_screen.dart';
import '../chat/chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await _apiService.get('/notifications');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _notifications = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.post('/notifications/read-all', {});
      _fetchNotifications();
    } catch (_) {}
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _apiService.post('/notifications/$id/read', {});
    } catch (_) {}
  }

  Future<void> _handleFollowRequest(String requestId, bool accept) async {
    final endpoint = accept ? '/social/requests/$requestId/accept' : '/social/requests/$requestId/reject';
    try {
      final response = await _apiService.post(endpoint, {});
      if (response.statusCode == 200) {
        _fetchNotifications();
      }
    } catch (_) {}
  }

  void _onNotificationTap(dynamic n) {
    final String id = n['id'] ?? n['_id'] ?? '';
    if (id.isNotEmpty && n['read'] != true) {
      _markAsRead(id);
      setState(() {
        n['read'] = true;
      });
    }

    final String fromUser = n['from_user'] ?? 'User';
    final String type = n['type'] ?? '';
    final metadata = n['metadata'] ?? {};

    if (type.contains("message") || type.contains("share") || type.contains("story_reply") || type.contains("story_reaction")) {
      final chatId = metadata['chat_id'];
      if (chatId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherUser: fromUser)),
        );
        return;
      }
    }

    if (fromUser.isNotEmpty && fromUser != 'User') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(username: fromUser)),
      );
    }
  }

  List<dynamic> _filterNotifications(int tabIndex) {
    if (tabIndex == 1) {
      return _notifications.where((n) => ['follow', 'follow_request', 'follow_accept'].contains(n['type'])).toList();
    } else if (tabIndex == 2) {
      return _notifications.where((n) => n['type'] == 'mention' || (n['message'] ?? '').contains('@')).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white70),
            tooltip: "Mark all as read",
            onPressed: _markAllAsRead,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Following"),
            Tab(text: "Mentions"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListView(_filterNotifications(0)),
                _buildListView(_filterNotifications(1)),
                _buildListView(_filterNotifications(2)),
              ],
            ),
    );
  }

  Widget _buildListView(List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(child: Text("No notifications here", style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildNotificationItem(items[index]),
    );
  }

  Widget _buildNotificationItem(dynamic n) {
    final String fromUser = n['from_user'] ?? 'User';
    final String? senderPhoto = n['sender_photo'];
    final bool isRead = n['read'] == true;
    final String type = n['type'] ?? '';
    final String message = n['message'] ?? '';
    final bool isRequest = type == "follow_request";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRead ? Colors.white10 : const Color(0xFF6C63FF).withValues(alpha: 0.4)),
      ),
      child: ListTile(
        onTap: () => _onNotificationTap(n),
        leading: SafeAvatar(
          avatarUrl: senderPhoto,
          username: fromUser,
          radius: 22,
        ),
        title: Text(
          message.isNotEmpty ? message : "@$fromUser interacted with you",
          style: TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            "Recent",
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ),
        trailing: isRequest && n['metadata']?['request_id'] != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _handleFollowRequest(n['metadata']['request_id'], true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(60, 30),
                    ),
                    child: const Text("Accept", style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => _handleFollowRequest(n['metadata']['request_id'], false),
                    child: const Text("Ignore", style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ),
                ],
              )
            : (!isRead
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                  )
                : null),
      ),
    );
  }
}
