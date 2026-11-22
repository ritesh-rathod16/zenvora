import 'package:flutter/material.dart';

class StickerPickerSheet extends StatelessWidget {
  final Function(String stickerType, Map<String, dynamic> data) onStickerSelected;

  const StickerPickerSheet({
    super.key,
    required this.onStickerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> interactiveStickers = [
      {"label": "LOCATION", "icon": Icons.location_on_rounded, "color": Colors.redAccent, "type": "location"},
      {"label": "@MENTION", "icon": Icons.alternate_email_rounded, "color": Colors.orangeAccent, "type": "mention"},
      {"label": "#HASHTAG", "icon": Icons.tag_rounded, "color": const Color(0xFF00D2FF), "type": "hashtag"},
      {"label": "POLL", "icon": Icons.poll_rounded, "color": const Color(0xFF6C63FF), "type": "poll"},
      {"label": "QUESTIONS", "icon": Icons.help_outline_rounded, "color": Colors.pinkAccent, "type": "questions"},
      {"label": "MUSIC", "icon": Icons.music_note_rounded, "color": Colors.purpleAccent, "type": "music"},
      {"label": "TIME", "icon": Icons.access_time_rounded, "color": Colors.amberAccent, "type": "time"},
      {"label": "COUNTDOWN", "icon": Icons.timer_rounded, "color": Colors.greenAccent, "type": "countdown"},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search stickers & GIFs...",
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0F0F1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: interactiveStickers.length,
              itemBuilder: (context, index) {
                final sticker = interactiveStickers[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onStickerSelected(sticker['type'], {"label": sticker['label']});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (sticker['color'] as Color).withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(sticker['icon'] as IconData, color: sticker['color'] as Color, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          sticker['label'] as String,
                          style: TextStyle(color: sticker['color'] as Color, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
