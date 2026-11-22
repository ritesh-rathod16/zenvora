import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StickerPickerSheet extends StatefulWidget {
  final Function(String stickerType, Map<String, dynamic> data) onStickerSelected;
  final Function(String gifUrl) onGifSelected;

  const StickerPickerSheet({
    super.key,
    required this.onStickerSelected,
    required this.onGifSelected,
  });

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _gifResults = [
    "https://media.giphy.com/media/3o7TKSjRrfIPjeiOkM/giphy.gif",
    "https://media.giphy.com/media/xT9IgzoKnwFNmISR8I/giphy.gif",
    "https://media.giphy.com/media/3og0IPxMM0erATueVW/giphy.gif",
    "https://media.giphy.com/media/l0HlBO7v3XSLqDMkw/giphy.gif",
    "https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif",
    "https://media.giphy.com/media/3oKIPnAiaMCws8nOsE/giphy.gif",
  ];
  bool _isSearchingGifs = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchGifs(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearchingGifs = true);
    try {
      // Using public GIPHY trending/search public beta key endpoint
      final url = Uri.parse("https://api.giphy.com/v1/gifs/search?api_key=dc6zaTOxFJmzC&q=$query&limit=20");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        if (mounted) {
          setState(() {
            _gifResults = list.map<String>((g) => g['images']['fixed_height']['url'].toString()).toList();
          });
        }
      }
    } catch (_) {
      // Fallback curated GIFs
    } finally {
      if (mounted) setState(() => _isSearchingGifs = false);
    }
  }

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
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const TabBar(
              indicatorColor: Color(0xFF6C63FF),
              labelColor: Color(0xFF6C63FF),
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: "Stickers"),
                Tab(text: "GIFs"),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  // Stickers Tab
                  GridView.builder(
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
                          widget.onStickerSelected(sticker['type'], {"label": sticker['label']});
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

                  // GIFs Tab
                  Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        onChanged: _searchGifs,
                        decoration: InputDecoration(
                          hintText: "Search GIPHY GIFs...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F0F1A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isSearchingGifs)
                        const LinearProgressIndicator(color: Color(0xFF6C63FF)),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _gifResults.length,
                          itemBuilder: (context, index) {
                            final url = _gifResults[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                widget.onGifSelected(url);
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.white10),
                                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
