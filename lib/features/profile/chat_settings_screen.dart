import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;

  String _allowMessagesFrom = "everyone"; // everyone, following, followers, nobody
  bool _allowMessageRequests = true;
  String _allowGroupAdds = "everyone"; // everyone, following, nobody
  bool _readReceipts = true;
  bool _typingIndicators = true;
  bool _onlineStatus = true;
  bool _lastSeen = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await _apiService.get('/chats/settings');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final cs = data['chat_settings'] ?? {};
        setState(() {
          _allowMessagesFrom = cs['allow_messages_from'] ?? "everyone";
          _allowMessageRequests = cs['allow_message_requests'] ?? true;
          _allowGroupAdds = cs['allow_group_adds'] ?? "everyone";
          _readReceipts = cs['read_receipts_enabled'] ?? true;
          _typingIndicators = cs['typing_indicators_enabled'] ?? true;
          _onlineStatus = cs['online_status_enabled'] ?? true;
          _lastSeen = cs['last_seen_enabled'] ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _apiService.put('/chats/settings', {
        'allow_messages_from': _allowMessagesFrom,
        'allow_message_requests': _allowMessageRequests,
        'allow_group_adds': _allowGroupAdds,
        'read_receipts_enabled': _readReceipts,
        'typing_indicators_enabled': _typingIndicators,
        'online_status_enabled': _onlineStatus,
        'last_seen_enabled': _lastSeen,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chat settings updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving chat settings: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Messages and Chats", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildHeader("MESSAGE CONTROLS"),
                _buildRadioTile("Allow Messages From", "Everyone", "everyone", _allowMessagesFrom, (val) {
                  setState(() => _allowMessagesFrom = val);
                  _saveSettings();
                }),
                _buildRadioTile("Allow Messages From", "People You Follow", "following", _allowMessagesFrom, (val) {
                  setState(() => _allowMessagesFrom = val);
                  _saveSettings();
                }),
                _buildRadioTile("Allow Messages From", "Followers", "followers", _allowMessagesFrom, (val) {
                  setState(() => _allowMessagesFrom = val);
                  _saveSettings();
                }),
                _buildRadioTile("Allow Messages From", "Nobody", "nobody", _allowMessagesFrom, (val) {
                  setState(() => _allowMessagesFrom = val);
                  _saveSettings();
                }),

                const Divider(color: Colors.white10, height: 24),
                SwitchListTile(
                  title: const Text("Allow Message Requests", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Receive message requests from people you don't follow.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _allowMessageRequests,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _allowMessageRequests = val);
                    _saveSettings();
                  },
                ),

                _buildHeader("RECEIPTS & ACTIVITY STATUS"),
                SwitchListTile(
                  title: const Text("Read Receipts", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Let others know when you have viewed their messages.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _readReceipts,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _readReceipts = val);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Typing Indicators", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Show when you are typing a message.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _typingIndicators,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _typingIndicators = val);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Show Online Status", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Allow friends to see when you are active on Zenvora.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _onlineStatus,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _onlineStatus = val);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Show Last Seen", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Display when you were last active in chats.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _lastSeen,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _lastSeen = val);
                    _saveSettings();
                  },
                ),

                _buildHeader("GROUP CHATS"),
                _buildRadioTile("Group Chat Adds", "Everyone", "everyone", _allowGroupAdds, (val) {
                  setState(() => _allowGroupAdds = val);
                  _saveSettings();
                }),
                _buildRadioTile("Group Chat Adds", "People You Follow", "following", _allowGroupAdds, (val) {
                  setState(() => _allowGroupAdds = val);
                  _saveSettings();
                }),
                _buildRadioTile("Group Chat Adds", "Nobody", "nobody", _allowGroupAdds, (val) {
                  setState(() => _allowGroupAdds = val);
                  _saveSettings();
                }),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildRadioTile(String category, String title, String value, String groupValue, Function(String) onChanged) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value: value,
      groupValue: groupValue,
      activeColor: const Color(0xFF6C63FF),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}
