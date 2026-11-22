import 'package:flutter/material.dart';

class MusicPickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic> track) onTrackSelected;

  const MusicPickerSheet({
    super.key,
    required this.onTrackSelected,
  });

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final List<Map<String, dynamic>> _tracks = [
    {"title": "Midnight City", "artist": "M83", "duration": "0:30", "genre": "Synthwave"},
    {"title": "Starboy", "artist": "The Weeknd", "duration": "0:30", "genre": "Pop"},
    {"title": "Lofi Chill Vibes", "artist": "Zenvora Beats", "duration": "0:30", "genre": "Lo-Fi"},
    {"title": "Neon Lights", "artist": "CyberWave", "duration": "0:30", "genre": "Electronic"},
    {"title": "Sunset Drive", "artist": "Kavinsky", "duration": "0:30", "genre": "Retro"},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          const Text("Music Library", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search music or artists...",
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0F0F1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF6C63FF).withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.music_note_rounded, color: Color(0xFF6C63FF)),
                  ),
                  title: Text(track['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("${track['artist']} • ${track['genre']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.play_circle_outline_rounded, color: Colors.white70),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onTrackSelected(track);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
