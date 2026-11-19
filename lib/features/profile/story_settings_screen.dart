import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import 'close_friends_screen.dart';
import 'hide_story_from_screen.dart';

class StorySettingsScreen extends StatefulWidget {
  const StorySettingsScreen({super.key});

  @override
  State<StorySettingsScreen> createState() => _StorySettingsScreenState();
}

class _StorySettingsScreenState extends State<StorySettingsScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;

  String _allowReplies = "everyone"; // everyone, following, nobody
  bool _allowReactions = true;
  bool _allowLikes = true;
  bool _allowSharing = true;
  String _allowMentions = "everyone"; // everyone, following, nobody
  bool _saveToArchive = true;
  bool _saveOriginal = true;

  int _closeFriendsCount = 0;
  int _hideFromCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await _apiService.get('/stories/settings');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final st = data['story_settings'] ?? {};
        setState(() {
          _allowReplies = st['allow_story_replies'] ?? "everyone";
          _allowReactions = st['allow_story_reactions'] ?? true;
          _allowLikes = st['allow_story_likes'] ?? true;
          _allowSharing = st['allow_story_sharing'] ?? true;
          _allowMentions = st['allow_story_mentions'] ?? "everyone";
          _saveToArchive = st['save_to_archive'] ?? true;
          _saveOriginal = st['save_original'] ?? true;

          final cf = data['close_friends'] as List? ?? [];
          final hf = data['hide_story_from'] as List? ?? [];
          _closeFriendsCount = cf.length;
          _hideFromCount = hf.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _apiService.put('/stories/settings', {
        'allow_story_replies': _allowReplies,
        'allow_story_reactions': _allowReactions,
        'allow_story_likes': _allowLikes,
        'allow_story_sharing': _allowSharing,
        'allow_story_mentions': _allowMentions,
        'save_to_archive': _saveToArchive,
        'save_original': _saveOriginal,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story settings updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating story settings: $e")),
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
        title: const Text("Story Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                _buildHeader("VIEWING & PRIVACY"),
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
                  title: const Text("Hide Story From", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text("$_hideFromCount people hidden", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HideStoryFromScreen()),
                    ).then((_) => _fetchSettings());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_outline_rounded, color: Colors.greenAccent),
                  title: const Text("Close Friends", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text("$_closeFriendsCount people on list", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CloseFriendsScreen()),
                    ).then((_) => _fetchSettings());
                  },
                ),

                _buildHeader("ALLOW STORY REPLIES & INTERACTIONS"),
                _buildRadioTile("Allow Story Replies", "Everyone", "everyone", _allowReplies, (val) {
                  setState(() => _allowReplies = val);
                  _saveSettings();
                }),
                _buildRadioTile("Allow Story Replies", "People You Follow", "following", _allowReplies, (val) {
                  setState(() => _allowReplies = val);
                  _saveSettings();
                }),
                _buildRadioTile("Allow Story Replies", "Off (Nobody)", "nobody", _allowReplies, (val) {
                  setState(() => _allowReplies = val);
                  _saveSettings();
                }),

                const Divider(color: Colors.white10, height: 24),
                SwitchListTile(
                  title: const Text("Allow Story Reactions", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Allow viewers to send quick emoji reactions to your DM.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _allowReactions,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _allowReactions = val);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Allow Story Likes", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Allow viewers to tap heart to like your stories.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _allowLikes,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _allowLikes = val);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Allow Story Sharing", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Allow viewers to share your story via DMs.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _allowSharing,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _allowSharing = val);
                    _saveSettings();
                  },
                ),

                _buildHeader("SAVING & ARCHIVING"),
                SwitchListTile(
                  title: const Text("Save Stories to Archive", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Automatically save your stories to your private archive after 24h.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _saveToArchive,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _saveToArchive = val);
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text("Save Original Stories to Gallery", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Automatically save stories you upload to device storage.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _saveOriginal,
                  activeTrackColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    setState(() => _saveOriginal = val);
                    _saveSettings();
                  },
                ),
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
